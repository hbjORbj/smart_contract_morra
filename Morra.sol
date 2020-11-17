pragma solidity >=0.4.22 <0.7.0;

contract Morra {

    uint constant public MIN_BET        = 1 finney;    // The minimum bet
    uint public initialBet;                            // Bet of first player

    enum Moves {None, One, Two, Three, Four, Five} // Possible moves (pick or guess)
    enum Outcomes {None, PlayerA, PlayerB, Draw}   // Possible outcomes

    // Players' addresses
    address payable playerA;
    address payable playerB;

    // Encrypted moves
    bytes32 private encryptedMovePlayerA;
    bytes32 private encryptedMovePlayerB;

    // Clear moves; they are set only after both players have committed their encrypted moves
    Moves private pickPlayerA;
    Moves private pickPlayerB;
    Moves private guessPlayerA;
    Moves private guessPlayerB;
    
    /* 
    REGISTRATION PHASE
    */
    
    // Both players must have not already been registered
    modifier isNotRegistered() {
        require(msg.sender != playerA && msg.sender != playerB);
        _;
    }

    // Bet must be greater than the minimum amount (1 finney)
    // AND greater than or equal to the bet of the first player
    modifier isValidBet() {
        require(msg.value >= MIN_BET);
        require(msg.value >= initialBet);
        _;
    }

    // Register a player.
    // Return player's ID upon successful registration.
    function register() public payable isNotRegistered isValidBet returns (uint) {
        if (playerA == address(0x0)) {
            playerA    = msg.sender;
            initialBet = msg.value;
            return 1;
        } else if (playerB == address(0x0)) {
            playerB = msg.sender;
            return 2;
        }
        return 0;
    }
    
    /*
    COMMIT PHASE
    */

    // Player committing must be already registered
    modifier isRegistered() {
        require (msg.sender == playerA || msg.sender == playerB);
        _;
    }

    // Save player's encrypted move (hash).
    // Return true if move was valid (there is no encrypted move saved yet), false otherwise.
    function play(bytes32 encryptedMove) public isRegistered returns (bool) {
        if (msg.sender == playerA && encryptedMovePlayerA == 0x0) {
            encryptedMovePlayerA = encryptedMove;
        } else if (msg.sender == playerB && encryptedMovePlayerB == 0x0) {
            encryptedMovePlayerB = encryptedMove;
        } else {
            return false;
        }
        return true;
    }
    
    // User should use this to get the hash of their string and enter into the input field for the play() method
    function getHash(string memory moveToEncrypt) public pure returns (bytes32) {
        bytes32 encrypted = sha256(abi.encodePacked(moveToEncrypt));
        return encrypted;
    }

    /*
    REVEAL PHASE
    */
    
    // Both players' encrypted moves are saved to the contract
    modifier commitPhaseEnded() {
        require(encryptedMovePlayerA != 0x0 && encryptedMovePlayerB != 0x0);
        _;
    }

    // Compare clear move given by the player with saved encrypted move.
    // Return the player's pick upon success, exit otherwise.
    function reveal(string memory clearMove) public isRegistered commitPhaseEnded returns (Moves) {
        bytes32 encryptedMove = sha256(abi.encodePacked(clearMove)); // Hash of clear input ("pick-guess-password")
        Moves pick            = Moves(getPick(clearMove)); // Actual number the player picked
        Moves guess           = Moves(getGuess(clearMove)); // Actual number the player guessed
        
        // If the two hashes match, both pick and guess are saved
        if (msg.sender == playerA && encryptedMove == encryptedMovePlayerA) {
            pickPlayerA = pick;
            guessPlayerA = guess;
        } else if (msg.sender == playerB && encryptedMove == encryptedMovePlayerB) {
            pickPlayerB = pick;
            guessPlayerB = guess;
        } else {
            return Moves.None;
        }

        return pick;
    }

    // Return player's pick using clear move given by the player
    function getPick(string memory str) private pure returns (uint) {
        byte firstByte = bytes(str)[0];
        if (firstByte == 0x31) {
            return 1;
        } else if (firstByte == 0x32) {
            return 2;
        } else if (firstByte == 0x33) {
            return 3;
        } else if (firstByte == 0x34) {
            return 4;
        } else if (firstByte == 0x35) {
            return 5;
        } else {
            return 0;
        }
    }
    
    // Return player's guess using clear move given by the player
    function getGuess(string memory str) private pure returns (uint) {
        byte thirdByte = bytes(str)[2];
        if (thirdByte == 0x31) {
            return 1;
        } else if (thirdByte == 0x32) {
            return 2;
        } else if (thirdByte == 0x33) {
            return 3;
        } else if (thirdByte == 0x34) {
            return 4;
        } else if (thirdByte == 0x35) {
            return 5;
        } else {
            return 0;
        }
    }

    /*
    RESULT PHASE
    */
    
    // Compute the outcome and pay the winner(s) and return the outcome.
    function getOutcome() public returns (Outcomes) { 
        if (pickPlayerA == Moves.None || pickPlayerB == Moves.None ||
            guessPlayerA == Moves.None || guessPlayerB == Moves.None) {
                return Outcomes.None;
                // Both players' pick and guess must be valid
        }
            
        Outcomes outcome;

        if ((pickPlayerA == guessPlayerB && pickPlayerB == guessPlayerA) ||
           (pickPlayerA != guessPlayerB && pickPlayerB != guessPlayerA)) {
            outcome = Outcomes.Draw;
        } else if (pickPlayerB == guessPlayerA) {
            outcome = Outcomes.PlayerA;
        } else if (pickPlayerA == guessPlayerB) {
            outcome = Outcomes.PlayerB;
        }

        address payable addressA = playerA;
        address payable addressB = playerB;
        uint betPlayerA          = initialBet;
        reset();  // Reset game before paying in order to avoid reentrancy attacks
        pay(addressA, addressB, betPlayerA, outcome);

        return outcome;
    }

    // Pay the winner(s).
    function pay(address payable addressA, address payable addressB, uint betPlayerA, Outcomes outcome) private {
        if (outcome == Outcomes.PlayerA) {
            addressA.transfer(address(this).balance);
        } else if (outcome == Outcomes.PlayerB) {
            addressB.transfer(address(this).balance);
        } else {
            addressA.transfer(betPlayerA);
            addressB.transfer(address(this).balance);
        }
    }

    // Reset the game.
    function reset() private {
        initialBet      = 0;
        playerA         = address(0x0);
        playerB         = address(0x0);
        encryptedMovePlayerA = 0x0;
        encryptedMovePlayerB = 0x0;
        pickPlayerA     = Moves.None;
        guessPlayerA     = Moves.None;
        pickPlayerB     = Moves.None;
        guessPlayerB    = Moves.None;
    }
    
     /*
     HELPER FUNCTIONS
     */

    // Return the balance of the contract
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    // Return player's ID
    function IAm() public view returns (uint) {
        if (msg.sender == playerA) {
            return 1;
        } else if (msg.sender == playerB) {
            return 2;
        } else {
            return 0;
        }
    }

    // Return true if both players have commited a move, false otherwise.
    function bothPlayed() public view returns (bool) {
        return (encryptedMovePlayerA != 0x0 && encryptedMovePlayerB != 0x0);
    }

    // Return true if both players have revealed their move, false otherwise.
    function bothRevealed() public view returns (bool) {
        return (pickPlayerA != Moves.None && pickPlayerB != Moves.None 
                && guessPlayerA != Moves.None && guessPlayerB != Moves.None);
    }
}
