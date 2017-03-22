
contract Roles {
    enum Role { PLAYER, HOST }
    mapping(address => Role) role;

    modifier by(Role r) {
        require(role[msg.sender] == r);
        _;
    }
}

contract Dependencies {
    bool[256] completed;
    function step(uint i) internal returns(bool) {
        return completed[i]; 
    }
    event Completed(uint i);
    
    modifier first {
        _;
    }
    modifier only_after(bool condition) {
        require(condition);
        _;
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
}

contract MontyHallDep is GameDep {
    uint256 hidden_car;
    uint door1;
    uint goat;
    uint door2;
    uint car;

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

contract MontyHall is MontyHallDep {
    function player_won() constant returns(bool) {
        return goat == door1 || !open(car, hidden_car) || goat == car || door2 == car;
    }
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
