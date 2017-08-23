pragma solidity ^0.4.11;

import './SafeMath.sol';
import './Ownable.sol';

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `StandardToken` functions.
 */
contract RobinhoodCoin is Ownable {
    using SafeMath for uint256;

    event Robbery(address indexed _victim, address indexed _thief, uint256 _amountStolen);
    event Payday(address indexed _government, address indexed _worker, uint256 _amountPaid);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Tax(address indexed _taxPayer, address indexed _taxCollector, uint256 _value);

    mapping(address => uint256) balances;

    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;

    address[] public richDudes; // Addresses considered wealthy
    address public government;  // Address that collects the tax
    uint256 public taxPercent = 1; // Percent taxed on all transfers
    uint256 wealthy;            // Minimum amount to be considered wealthy

    /* Mining variables */
    bytes32 public currentChallenge;
    uint public timeOfLastRobbery; // time of last challenge solved
    uint public timeOfLastPayday; // time of last challenge solved
    uint256 public robberyDifficulty = 2**256 - 1; // Difficulty starts low
    uint256 public paydayDifficulty = 2**256 - 1; // Difficulty starts low


    /**
    * @dev Contructor that gives msg.sender all of existing tokens.
    */
    function RobinhoodCoin(
        string _name,
        string _symbol,
        uint256 _decimals,
        uint256 _totalSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;

        balances[msg.sender] = totalSupply;
        government = msg.sender;
        wealthy = totalSupply * 1 / 100; // you are wealthy if you have 1% or more of total supply.
    }

    /**
     * @dev Calculate the reward
     * @param _mineHost address Person who's money is being stolen
     * @return uint256 Returns the amount to reward
     */
    function calculateAmountToReceive(address _mineHost) returns (uint256 reward) {
        uint256 amountToRecieve = balances[_mineHost];
        reward = amountToRecieve * 10 / 100;
        if (reward > amountToRecieve) return amountToRecieve;

        return reward;
    }

    /**
     * @dev Proof of work to be done for mining
     * @param _mineHost address address being mined
     * @param _nonce uint
     * @return reward uint256 The amount rewarded
     */
    function mine(address _mineHost, uint _nonce) private returns (uint256 reward) {
        uint256 difficulty;
        uint timeOfLastMine;

        /* get the mining variables */
        if (_mineHost == government) {
            difficulty = paydayDifficulty;
            timeOfLastMine = timeOfLastPayday;
        } else if (isMarkedRich(_mineHost)) {
            difficulty = robberyDifficulty;
            timeOfLastMine = timeOfLastRobbery;
        } else {
            revert();
        }

        bytes32 n = sha3(_nonce, currentChallenge); // generate random hash based on input
        if (n > bytes32(difficulty)) revert();

        uint timeSinceLastMine = (now - timeOfLastMine); // Calculate time since last reward
        if (timeSinceLastMine < 5 seconds) revert(); // Do not reward too quickly

        reward = calculateAmountToReceive(_mineHost);

        transferFrom(_mineHost, msg.sender, reward); // reward to winner grows over time

        difficulty = difficulty * timeSinceLastMine / 10 minutes + 1; // Adjusts the difficulty

        currentChallenge = sha3(_nonce, currentChallenge, block.blockhash(block.number - 1)); // Save hash for next proof

        return reward;
    }

    /**
     * @dev Do proof of work to mine from the government address
     * @param _nonce uint
     * @return reward uint256 The amount rewarded
     */
    function GetPaid(uint _nonce) returns (uint256 reward) {
        /* Cancel Mine */
        if (msg.sender == government) revert(); // Government won't pay itself
        if (government == 0) revert(); // Government is out of money

        /* mine */
        reward = mine(government, _nonce);
        timeOfLastPayday = now;

        /* Update who's rich */
        if (balances[msg.sender] >= wealthy) richDudes.push(msg.sender); // msg.sender is now wealthy?

        Payday(government, msg.sender, reward); // execute an event reflecting the change

        return reward;
    }

    /**
     * @dev Do proof of work to mine from a richDudes address
     * @param _nonce uint
     * @return reward uint256 The amount rewarded
     */
    function TakeFromTheRich(uint _nonce) returns (uint256 reward) {
        /* Cancel mine */
        if (balances[msg.sender] >= wealthy) revert(); // Rich can't steal from the rich
        if (richDudes.length < 1) revert(); // There's no rich dudes

        address richDude = richDudes[now % richDudes.length]; // get a rich dude

        /* mine */
        reward = mine(richDude, _nonce);
        timeOfLastRobbery = now;

        /* Update who's rich */
        if (balances[msg.sender] >= wealthy) richDudes.push(msg.sender);                              // msg.sender is now wealthy?
        if (balances[richDude] < wealthy) unmarkRichDude(richDude);       // Rich dude is no longer wealthy?

        Robbery(richDude, msg.sender, reward); // execute an event reflecting the change

        return reward;
    }

    /**
     * @dev Determine if address is on the rich list
     * @param _address address
     * @return bool if _address is on the list or not
     */
    function isMarkedRich(address _address) private returns (bool) {
        for (uint i = 0; i < richDudes.length; i++) {
            if (richDudes[i] == _address) return true;
        }

        return false;
    }

    /**
    * @dev Remove address from list of richDudes
    * @param _address address The address to be removed from richDudes array
    * @return bool returns if address was deleted
    */
    function unmarkRichDude(address _address) returns (bool) {
        /* find where address is in rich array */
        for (uint x = 0; x < richDudes.length; x++) {
            if (richDudes[x] == _address) {
                uint index = x;
            } else {
                return false;
            }
        }

        richDudes[index] = richDudes[richDudes.length-1];

        delete richDudes[richDudes.length-1];
        richDudes.length--;

        return true;
    }


    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    /**
    * @dev Tax a transaction
    * @param _taxPayer address The address being taxed
    * @param _taxPayer address The address recieving the tax payment
    * @param _value uint256 amount of tokens being taxed
    */
    function tax(address _taxPayer, address _taxCollector, uint256 _value) private returns (bool){

        /* Check if no tax */
        if (_taxPayer == _taxCollector) return true; // Government won't pay itself
        if (taxPercent == 0) return true;         // Don't tax if 0 tax percent
        if (_taxCollector == 0x0) return true;         // Don't tax if no taxCollector

        /* calculate amount to tax */
        uint256 amountToTax = _value * taxPercent / 100;
        if (amountToTax == 0 && taxPercent > 0) amountToTax = 1;    // Minimum tax of 1

        /* transfer from tax payer to tax collector */
        transferFrom(_taxPayer, _taxCollector, amountToTax);

        Tax(_taxPayer, _taxCollector, amountToTax);

        return true;
    }

    /**
    * @dev Transfers token from one address to another
    * @param _from address The address where tokens are deducted
    * @param _to address The address where tokens are added to
    * @param _value uint256 amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint256 _value) private returns (bool) {
        if (_to == 0x0) revert();                               // Prevent transfer to 0x0 address. Use burn() instead
        if (balances[_from] < _value) revert();           // Check if the sender has enough
        if (balances[_to].add(_value) < balances[_to]) revert(); // Check for overflows
        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);

        return true;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) returns (bool) {
        transferFrom(msg.sender, _to, _value);

        tax(msg.sender, government, _value);

        if (balances[msg.sender] < wealthy) unmarkRichDude(msg.sender); // taxPayer is no longer wealthy?
        if (balances[_to] >= wealthy && !isMarkedRich(_to)) richDudes.push(_to); // Recipient is now wealthy?

        Transfer(msg.sender, _to, _value);

        return true;
    }

    /**
    * @dev Set the percentage taxed on transfer
    * @param _newTaxPercent uint Percent to be taxed
    */
    function setTaxPercent(uint _newTaxPercent) onlyOwner {
        if (_newTaxPercent < 0 || _newTaxPercent > 100) revert();
        taxPercent = _newTaxPercent;
    }


}
