
contract Dependencies {
    uint[5] deps;
    bool[5] completed;
    
    event Completed(uint i);
    
    modifier depends_on0() {
        _;
    }
    // TODO: depends_on(variable). requires some sort of optional type
    modifier depends_on1(uint dep) {
        require(completed[deps[dep]]);
        _;
    }
    modifier depends_on2(uint dep1, uint dep2) {
        require(completed[deps[dep1]]);
        require(completed[deps[dep2]]);
        _;
    }
    modifier id(uint i) {
        require(!completed[i]);
        _;
        completed[i] = true;
        Completed(i);
    }
}

contract Roles {
    enum Role { PLAYER, HOST }
    mapping(address => Role) role;

    modifier by(Role r) {
        require(role[msg.sender] == r);
        _;
    }
}

contract Game is Roles, Dependencies { 
    function open(uint value, uint commitment) {
        require(sha3(value) == bytes32(commitment));
    }
    function open(int value, uint commitment) {
        require(sha3(value) == bytes32(commitment));
    }
}

contract MontyHall is Game {
    uint256 hidden_car;
    int door1;
    int goat;
    int door2;
    int car;

    function hide_car(uint256 commitment) by(Role.HOST) id(0) depends_on0() {
        hidden_car = commitment;
    }
    function play_door1(int value) by(Role.PLAYER) id(1) depends_on1(0) {
        door1 = value;
    }
    function play_goat(int value) by(Role.HOST) id(2) depends_on1(1) {
        goat = value;
    }
    function play_door2(int value) by(Role.PLAYER) id(3) depends_on1(2) {
        door2 = value;
    }
    function reveal_car(int value) by(Role.HOST) id(4) depends_on1(3) {
        open(value, hidden_car);
        car = value;
    }
}

contract STPG is Game {
    uint256 hidden_choice1;
    int choice1;
    uint256 hidden_choice2;
    int choice2;

    function hide_choice1(uint256 commitment) by(Role.HOST) id(0) depends_on0() {
        hidden_choice1 = commitment;
    }
    function hide_choice2(uint256 commitment) by(Role.PLAYER) id(1) depends_on0() {
        hidden_choice2 = commitment;
    }
    function reveal_choice1(int value) by(Role.HOST) id(2) depends_on1(1) {
        open(value, hidden_choice2);
        choice2 = value;
    }
    function reveal_choice2(int value) by(Role.HOST) id(3) depends_on1(0) {
        open(value, hidden_choice1);
        choice1 = value;
    }
}
