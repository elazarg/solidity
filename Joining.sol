pragma solidity ^0.4.11;

contract Join {
    // Parameters: (uint 2, address NewContract)
    address creator;
    function Join() {
        // The only use of creator is to pay back the contract creation
        // So tx.origin seems useful, since it has no permissions attached
        // this is _not_ an owner!
        creator = tx.origin;
    }
    
    uint private next = 0;
    address[2] players = [0x0, 0x0];

    event NotifyStart(address);

    function join() {
        // The following line would have been an assert() if we were running start() automatically
        // Note that a conforming client could execute this function accidentally due to a race condition.
        // This is another reason why we shouldn't run start() instead of revert()
        if (! (next < players.length)) revert();
        assert(players[next] == 0x0);

        // Just a thought: putting tx.origin here will give us only external accounts
        // Or we can require(msg.sender == tx.origin)
        players[next] = msg.sender;
        next++;
    }
    
    function start() {
        require(next == players.length);
        address game = new NewContract(players);
        NotifyStart(game);
        selfdestruct(creator);
    }
    
    function cancel() {
        // Does not scale to more than two players
        // Is ownership important?
        
        // Idea: for more players, only remove the first cancelers,
        // and selfdestruct to the last one
        require(msg.sender == players[0]);
        assert(players[1] == 0x0);
        selfdestruct(players[0]);
    }
}

contract NewContract {
    //[...]
    address[2] players;
    function NewContract(address[2] _players) {
        players = _players;
    }
}

contract Game {
    address p0;
    address p1;
    function Game(address _p0, address _p1) {
        p0 = _p0;
        p1 = _p1;
    }
    
    //[...]
}

