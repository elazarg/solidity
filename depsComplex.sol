pragma solidity ^0.4.11;

contract Roles {
    enum Role { PLAYER, HOST, TIMER }
    mapping(address => Role) private role;

    modifier by(Role r) {
        require(role[msg.sender] == r);
        _;
    }
}

contract Dependencies {
    bool[256] private completed;
    function step(uint i) internal returns(bool) {
        return completed[i]; 
    }
    event Completed(uint);
    
    modifier first {
        _;
    }
    modifier only_after(bool condition) {
        require(condition);
        _;
    }

    modifier repeat_step(uint i) {
        require(!step(i));
        _;
    }
    
    modifier complete_step(uint i) {
        assert(!step(i));
        _;
        completed[i] = true;
        assert(step(i));
        Completed(i);
    }
    
    modifier perform_step(uint i) {
        require(!step(i));
        _;
        completed[i] = true;
        assert(step(i));
        Completed(i);
    }
}

contract GameDep is Roles, Dependencies { 
    function open(uint value, uint commitment) internal constant returns(bool) {
        return sha3(value) == bytes32(commitment);
    }
    function open(int value, uint commitment) internal constant returns(bool) {
        return open(uint(value), commitment);
    }
    // Helper. Do _not_ call online.
    function commit_with_sender(uint value) constant returns(bytes32) {
        return sha3(value, msg.sender);
    }
    function open_with_sender(uint value, uint commitment) internal constant returns(bool) {
        return sha3(value, msg.sender) == bytes32(commitment);
    }
}

contract MontyHallDep is GameDep {
    uint256 private hidden_car;
    uint public door1;
    uint public goat;
    uint public door2;
    uint public car;

    function hide_car(uint256 commitment) perform_step(0) by(Role.HOST) first {
        hidden_car = commitment;
    }
    function play_door1(uint value) perform_step(1) by(Role.PLAYER) only_after(step(0)) {
        door1 = value;
    }
    function play_goat(uint value) perform_step(2) by(Role.HOST) only_after(step(1)) {
        goat = value;
    }
    function play_door2(uint value) perform_step(3) by(Role.PLAYER) only_after(step(2)) {
        door2 = value;
    }
    function reveal_car(uint value) perform_step(4) by(Role.HOST) only_after(step(3)) {
        car = value;
    }
}

contract LazySendEther {
    mapping(address => uint256) public money;
    function withdraw() {
        uint256 amount = money[msg.sender];
        require(amount > 0);
        money[msg.sender] = 0;
        msg.sender.transfer(amount);
        assert(money[msg.sender] == 0);
    }
    function send_to(address to) payable {
        uint256 amount = msg.value;
        assert(money[to] + amount > money[to]);
        money[to] += amount;
    }
}

contract SendEther {
    address private target;
    function SendEther(address _target) payable {
        target = _target;
    }
    function withdraw() {
        selfdestruct(target);
    }
}

contract Auction is GameDep {
    function Auction(LazySendEther _money) {
        money = _money;
        owner = msg.sender;
        //timer.set(this.finish_bidding, 30);
    }
    address owner;
    LazySendEther money;

    uint public max;
    address public winner;
    event Winner(address);

    function bidding() repeat_step(0) by(Role.PLAYER) first payable {
        require(msg.value > DEPOSIT);
        if (msg.value <= max)
            revert();
        money.send_to.value(max)(winner);
        max = msg.value;
        winner = msg.sender;
    }

    function finish_bidding() complete_step(0) by(Role.TIMER) { 
        money.send_to.value(PRICE)(winner);
        Winner(winner);
        selfdestruct(owner);
    }
    
    uint256 constant DEPOSIT = 0;
    uint256 constant PRICE = 0;
}

contract BlindAuction is GameDep {
    function BlindAuction(LazySendEther _money) {
        money = _money;
        owner = msg.sender;
        //timer.set(this.finish_bidding, 30);
        //timer.set(this.finish_reveal, 60);
    }
    address owner;
    LazySendEther money;
    
    mapping(address => uint) private commitments;
    
    uint public max;
    address public winner;
    event Winner(address);

    function hide_price(uint256 commitment) repeat_step(0) by(Role.PLAYER) first payable {
        require(msg.value == DEPOSIT);
        commitments[msg.sender] = commitment;
    }

    function finish_bidding() complete_step(0) by(Role.TIMER) { }

    function reveal_price(uint value) repeat_step(1) by(Role.PLAYER) only_after(step(0)) payable {
        require(open_with_sender(value, commitments[msg.sender]));
        require(msg.value == value);
        if (value <= max)
            revert();
        max = value;
        winner = msg.sender;
    }

    function finish_reveal() complete_step(1) by(Role.TIMER) {
        Winner(winner);
    }

    function withdraw() perform_step(2) by(Role.PLAYER) only_after(step(1)) {
        require(commitments[msg.sender] != 0);
        delete commitments[msg.sender];
        msg.sender.transfer(DEPOSIT);
        if (msg.sender == winner) {
            msg.sender.transfer(PRICE);
        }
    }
    
    function finish_withdraw() complete_step(2) by(Role.TIMER) { 
        selfdestruct(owner);
    }
    
    uint256 constant DEPOSIT = 0;
    uint256 constant PRICE = 0;
}

contract STPGDep is GameDep {
    uint256 hidden_choice1;
    uint choice1;
    uint256 hidden_choice2;
    uint choice2;

    function hide_choice1(uint256 commitment) perform_step(0) by(Role.HOST) first {
        hidden_choice1 = commitment;
    }
    function hide_choice2(uint256 commitment) perform_step(1) by(Role.PLAYER) first {
        hidden_choice2 = commitment;
    }
    function reveal_choice1(uint value) perform_step(2) by(Role.HOST) only_after(step(1)) {
        choice2 = value;
    }
    function reveal_choice2(uint value) perform_step(3) by(Role.PLAYER) only_after(step(0)) {
        choice1 = value;
    }
}

contract MontyHall is MontyHallDep {
    function player_won(uint door1, uint goat, uint hidden_car, uint car) constant returns(bool) {
        return goat == door1 || !open(car, hidden_car) || goat == car || door2 == car;
    }
}

contract STPG is STPGDep {
    
    function judge(uint choice1, uint choice2) internal returns (uint index);
    
    function payment() constant internal returns (uint[3]);
    
    uint256 constant PENALTY = 0; // = 10 ether;
    uint256 constant COST = 0; // = 100 ether;

    function player1_won() constant returns(bool) {
        return !open(choice1, hidden_choice1) || open(choice1, hidden_choice1) && judge(choice1, choice2) == 0;
    }
}

contract RockPaperScissors is STPG {
    function judge(uint choice1, uint choice2) internal returns (uint index) {
        uint8 diff = uint8((choice1 % 3 - choice2 % 3) % 3);
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

contract OddsAndEvens is STPG {
    function judge(uint odd, uint even) internal returns (uint index) {
        uint diff = (odd % 2 + even % 2);
        return (diff % 2 == 0) ? 1 : 2;
    }
    
    function payment() constant internal returns (uint[3]) {
        return [0,
                COST + 0    + PENALTY,
                0    + 0    + PENALTY];
    }
}
