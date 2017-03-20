pragma solidity ^0.4.0;

contract SimultaneousTwoPlayerGameI {
    /* Incentive-based simultaneous two player game:
    0. OFFLINE: 
    0.1: Choose a secret number.
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
    function commitment(uint v) constant returns(bytes32) {
        return sha3(v);
    }
}

contract SimultaneousTwoPlayerGame is SimultaneousTwoPlayerGameI {
    
    function judge(uint secret1, uint secret2) internal returns (uint index);
    
    function payment() constant internal returns (uint[3]);
    
    uint256 constant PENALTY = 0; // = 10 ether;
    uint256 constant COST = 0; // = 100 ether;

    enum State { JOIN1, JOIN2,
                 REVEAL1, REVEAL2,
                 COLLECT1, COLLECT2,
                 DONE }

    State state = State.JOIN1;
    bytes32[2] commitments;
    mapping(bytes32 => address) players;
    mapping(bytes32 => uint) revealedSecret;

    function deposit(bytes32 token) payable validStates(State.JOIN1, State.JOIN2) {
        if (msg.value != COST + PENALTY)
            throw;
        if (players[token] != 0)
            throw;
        players[token] = msg.sender;
        commitments[uint(state)] = token;
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
        bytes32 c = magic.commitment(secret);
        if (players[c] == 0 || revealedSecret[c] != 0)
            throw;
        revealedSecret[c] = secret;
    }
    
    function collect(bytes32 token) validStates(State.COLLECT1, State.COLLECT2) {
        bytes32 opponentToken = (token == commitments[0]) ? commitments[1] : commitments[0];
        uint index = judge(revealedSecret[token], revealedSecret[opponentToken]);
        uint[3] memory p = payment();
        address player = players[token];
        delete players[token];
        // Reentrancy is fine
        if (!player.send(payment()[index]))
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
        delete revealedSecret[commitments[0]];
        delete revealedSecret[commitments[1]];

        // These have been already cleaned, but we want to allow local reasoning:
        delete players[commitments[0]];
        delete players[commitments[1]];

        delete commitments;
    }
}

contract RockPaperScissors is SimultaneousTwoPlayerGame {
    function judge(uint secret1, uint secret2) internal returns (uint index) {
        uint8 diff = uint8((secret1 % 3 - secret2 % 3) % 3);
        if (diff == 0) return 0;
        if (diff == 1) return 1;
        if (diff == 2) return 2;
        throw;
    }
    
    function payment() constant internal returns (uint[3]) {
        return [COST + COST + PENALTY,
                COST + 0    + PENALTY,
                0    + 0    + PENALTY];
    }
}

contract OddsAndEvens is SimultaneousTwoPlayerGame {
    function judge(uint secret1, uint secret2) internal returns (uint index) {
        uint diff = (secret1 % 2 + secret2 % 2);
        return (diff % 2 == 0) ? 1 : 2;
    }
    
    function payment() constant internal returns (uint[3]) {
        return [0,
                COST + 0    + PENALTY,
                0    + 0    + PENALTY];
    }
}
