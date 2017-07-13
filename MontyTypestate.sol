pragma solidity ^0.4.11;

// we get here using JoinWithPenalty
contract State {
    event NextState(State);
}

contract MontyGame is State {
    address H;
    address G;
    
    function MontyGame(address _H, address _G) {
        H = _H;
        G = _G;
    }
    
    function hiddenCar(bytes32 hiddenCar) {
        require(msg.sender == H);
        NextState(new MontyGame_HiddenCar(H, G, hiddenCar));
    }
}

contract MontyGame_HiddenCar is State {
    address H;
    address G;
    bytes32 hiddenCar;
    
    function MontyGame_HiddenCar(address _H, address _G, bytes32 _hiddenCar) {
        H = _H;
        G = _G;
        hiddenCar = _hiddenCar;
    }
    
    function door1(int door1) {
        require(msg.sender == G);
        NextState(new MontyGame_HiddenCar_Door1(H, G, hiddenCar, door1));
    }
}

contract MontyGame_HiddenCar_Door1 is State {
    address H;
    address G;
    bytes32 hiddenCar;
    int door1;
    
    function MontyGame_HiddenCar_Door1(address _H, address _G, bytes32 _hiddenCar, int _door1) {
        H = _H;
        G = _G;
        hiddenCar = _hiddenCar;
        require(0 <= _door1 && _door1 < 3);
        door1 = _door1;
    }
    
    function goat(int goat) {
        require(msg.sender == H);
        NextState(new MontyGame_HiddenCar_Door1_Goat(H, G, hiddenCar, door1, goat));
    }
}


contract MontyGame_HiddenCar_Door1_Goat is State {
    address H;
    address G;
    bytes32 hiddenCar;
    int door1;
    int goat;
    
    function MontyGame_HiddenCar_Door1_Goat(address _H, address _G, bytes32 _hiddenCar, int _door1, int _goat) {
        H = _H;
        G = _G;
        hiddenCar = _hiddenCar;
        door1 = _door1;
        require(0 <= _goat && _goat < 3);
        goat = _goat;
    }
    
    function door2(int door2) {
        require(msg.sender == G);
        NextState(new MontyGame_HiddenCar_Door1_Goat_Door2(H, G, hiddenCar, door1, goat, door2));
    }
}

contract MontyGame_HiddenCar_Door1_Goat_Door2 is State {
    address H;
    address G;
    bytes32 hiddenCar;
    int door1;
    int goat;
    int door2;
    
    event GameOver(address, address);
    
    function MontyGame_HiddenCar_Door1_Goat_Door2(address _H, address _G, bytes32 _hiddenCar, int _door1, int _goat, int _door2) {
        H = _H;
        G = _G;
        hiddenCar = _hiddenCar;
        door1 = _door1;
        goat = _goat;
        door2 = _door2;
    }
    
    function reveal(int saltedCar) {
        require(msg.sender == H);
        int car = saltedCar % 3;
        if (sha3(saltedCar) != hiddenCar || goat == door1 || goat == car || door2 == car) {
            GameOver(new Winner(G), new Loser(H));
        } else {
            GameOver(new Winner(H), new Loser(G));
        }
    }
}

contract Winner {
    address w;
    function Winner(address _w) {
        w = _w;
    }
    
    function withdraw() {
        selfdestruct(w);
    }
}

contract Loser {
    address l;
    function Loser(address _l) {
        l = _l;
    }
    
    function withdraw() {
        selfdestruct(l);
    }
}
