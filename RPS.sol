pragma solidity ^0.4.0;

/* Incentive-based Rock-Scissors-Paper game:
1-2. deposit(hash): Player-by-player commit to sha3() of their secret choice, whose modulo-3 define its value
3: Players query state until it is equal to REVEAL1 or REVEAL2.
     ONLY THEN should they put the secret anywhere accessible to miners or anyone.
     DO NOT automate it using a contract in any way, unless you KNOW it will only execute on the client.
4-5. reveal(secret): Player-by-player they reveal their secret
6-7. collect(hash): Player-by-player they collect their share

The losing side might not reveal his secret, thus locking the winner's money,
but then he would lose the PENALTY forever along with COST. (Same goes for giving a fake hash.)
An alternative or complementary approach may use alarm_clock:
    http://www.ethereum-alarm-clock.com/

*/
contract RPS {
    uint256 constant PENALTY = 10 ether;
    uint256 constant COST = 100 ether;

    enum State { JOIN1, JOIN2,
                 REVEAL1, REVEAL2,
                 COLLECT1, COLLECT2,
                 DONE }

    State state = State.JOIN1;
    bytes32[2] hashes;
    mapping(bytes32 => address) players;
    mapping(bytes32 => int8) choice;

    function deposit(bytes32 hash) payable validStates(State.JOIN1, State.JOIN2) {
        if (msg.value != COST + PENALTY)
            throw;
        players[hash] = msg.sender;
        hashes[uint(state)] = hash;
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
        bytes32 hash = sha3(secret);
        if (players[hash] == 0 || choice[hash] != 0)
            throw;
        choice[hash] = int8(secret % 3) + 3;
    }
    
    function collect(bytes32 hash) validStates(State.COLLECT1, State.COLLECT2) {
        bytes32 opponentHash = (hash == hashes[0]) ? hashes[1] : hashes[0];
        uint result = gameResult(choice[hash], choice[opponentHash]);
        address player = players[hash];
        delete players[hash];
        // Reentrancy is fine
        if (!player.send(result))
            throw;
    }
    
    function gameResult(int8 choice1, int8 choice2) internal returns (uint) {
        if (choice1 == choice2)
            return COST + PENALTY;
        if ( (choice1 - choice2) % 3 == 1)
            return 2 * COST + PENALTY;
        return PENALTY;
    }

    modifier validStates(State from, State to) {
        if (state != from && state != to)
            throw;
        _;
        state = State(uint(state)+1);
        if (state == State.DONE)
            cleanup();
    }

    function cleanup() internal {
        delete choice[hashes[0]];
        delete choice[hashes[1]];
        delete hashes;
        // Questionable:
        state = State.JOIN1;
    }
}
