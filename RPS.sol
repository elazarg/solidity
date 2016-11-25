pragma solidity ^0.4.0;

contract RPSI {
    /* Incentive-based Rock-Scissors-Paper game:
    0. OFFLINE:
    0.1: Choose a secret number, whose value modulo-3 define whether it is a rock, a paper or scissors.
    0.2: Get magic.token(secret).
    
    1-2. deposit(token): Player-by-player commit to the token,
    3: Players query state until it is equal to REVEAL1 or REVEAL2.
         ONLY THEN should they put the secret anywhere accessible to miners or anyone.
         DO NOT automate it using a contract in any way, unless you KNOW it will only execute on the client.
    4-5. reveal(secret): Player-by-player they reveal their secret
    6-7. collect(token): Player-by-player they collect their share
    
    The losing side might not reveal his secret, thus locking the winner's money,
    but then he would lose the PENALTY forever along with COST. (Same goes for giving a fake hash.)
    An alternative or complementary approach may use alarm_clock:
        http://www.ethereum-alarm-clock.com/
    */

    function deposit(bytes32 hash) payable;
    function mayReveal() constant returns(bool);
    function reveal(uint secret);
    function collect(bytes32 hash);
}

library magic {
    // Helper function. Should only run LOCALLY by clients.
    function token(uint v) constant returns(bytes32) {
        return sha3(v);
    }
}

contract RPS is RPSI {
    uint256 constant PENALTY = 0; // = 10 ether;
    uint256 constant COST = 0; // = 100 ether;

    enum State { JOIN1, JOIN2,
                 REVEAL1, REVEAL2,
                 COLLECT1, COLLECT2,
                 DONE }

    State state = State.JOIN1;
    bytes32[2] tokens;
    mapping(bytes32 => address) players;
    mapping(bytes32 => int8) choice;

    function deposit(bytes32 token) payable validStates(State.JOIN1, State.JOIN2) {
        if (msg.value != COST + PENALTY)
            throw;
        players[token] = msg.sender;
        tokens[uint(state)] = token;
    }

    // Convenience function; this.state can be queried directly
    // You may only use reveal() if this function returns true
    function mayReveal() constant returns(bool) {
        if (state == State.REVEAL1 || state == State.REVEAL2)
            return true;
        if (state == State.JOIN2)
            return false;
        throw;
    }

    // Important: Any attempt to call this method reveals the secret,
    //            even if it is not executed for any reason.
    // assume: if a real player calls this, mayReveal() returns true.
    // The _test_ for this assumption is too late.
    function reveal(uint secret) validStates(State.REVEAL1, State.REVEAL2) {
        bytes32 t = magic.token(secret);
        if (players[t] == 0 || choice[t] != 0)
            throw;
        choice[t] = int8(secret % 3) + 3;
    }
    
    function collect(bytes32 token) validStates(State.COLLECT1, State.COLLECT2) {
        bytes32 opponentHash = (token == tokens[0]) ? tokens[1] : tokens[0];
        uint result = gameResult(choice[token], choice[opponentHash]);
        address player = players[token];
        delete players[token];
        // Reentrancy is fine
        if (!player.send(result))
            throw;
    }
    
    function gameResult(int8 choice1, int8 choice2) internal returns (uint) {
        int8 diff = (choice1 - choice2) % 3;
        //                      this player  | other player
        if (diff == 0) return COST + PENALTY + 0       + 0      ;
        if (diff == 1) return COST + PENALTY + COST    + 0      ;
        if (diff == 2) return 0    + 0       + 0       + PENALTY;
        throw;
    }

    modifier validStates(State from, State to) {
        if (state != from && state != to)
            throw;
        _;
        state = State(uint(state)+1);
        if (state == State.DONE) {
            cleanup();
            // Questionable:
            state = State.JOIN1;
        }
    }

    function cleanup() internal {
        delete choice[tokens[0]];
        delete choice[tokens[1]];

        // These have been already cleaned, but we want to allow local reasoning:
        delete players[tokens[0]];
        delete players[tokens[1]];

        delete tokens;
    }
}
