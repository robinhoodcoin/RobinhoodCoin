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
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Tax(address indexed _taxPayer, address indexed _taxCollector, uint256 _value);

    mapping(address => uint256) balances;

    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public totalSupply;

    address public richestDudeAround; // Address with the most tokens
    uint256 public taxPercent = 1; // Percent taxed on all transfers

    /* Mining variables */
    bytes32 public currentChallenge;
    uint public timeOfLastRobbery; // time of last challenge solved
    uint256 public difficulty = 2**256 - 1; // Difficulty starts low

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
        richestDudeAround = msg.sender;
    }

    /**
     * @dev Calculate the reward
     * @return uint256 Returns the amount to reward
     */
    function calculateAmountToSteal() returns (uint256 reward) {
        uint256 richMoney = balances[richestDudeAround];
        reward = richMoney * 1 / 100;
        if (reward > richMoney) return richMoney;

        return reward;
    }

    /**
     * @dev Proof of work to be done for mining
     * @param nonce uint
     * @return uint The amount rewarded
     */
    function TakeFromTheRich(uint nonce) returns (uint256 reward) {
        bytes32 n = sha3(nonce, currentChallenge); // generate random hash based on input
        if (n > bytes32(difficulty)) revert();

        uint timeSinceLastProof = (now - timeOfLastRobbery); // Calculate time since last reward
        if (timeSinceLastProof < 5 seconds) revert(); // Do not reward too quickly

        reward = calculateAmountToSteal();

        transferFrom(richestDudeAround, msg.sender, reward); // reward to winner grows over time

        if (balances[msg.sender] >= balances[richestDudeAround]) {
            richestDudeAround = msg.sender;
        }

        difficulty = difficulty * 10 minutes / timeSinceLastProof + 1; // Adjusts the difficulty

        timeOfLastRobbery = now;
        currentChallenge = sha3(nonce, currentChallenge, block.blockhash(block.number - 1)); // Save hash for next proof

        Robbery(richestDudeAround, msg.sender, reward); // execute an event reflecting the change

        return reward;
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
    * @param _value uint256 amount of tokens being taxed
    */
    function tax(address _taxPayer, uint256 _value) private returns (bool){
        if (_taxPayer == richestDudeAround) return true;

        uint256 amountToTax = _value * taxPercent / 100;
        if (amountToTax == 0) return true;
        if (balances[_taxPayer] < amountToTax) revert();           // Check if the sender has enough
        if (balances[richestDudeAround].add(amountToTax) < balances[richestDudeAround]) revert(); // Check for overflows

        balances[richestDudeAround] = balances[richestDudeAround].add(amountToTax);
        balances[_taxPayer] = balances[_taxPayer].sub(amountToTax);
        Tax(_taxPayer, richestDudeAround, amountToTax);
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
        Transfer(_from, _to, _value);
        return true;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) returns (bool) {
        transferFrom(msg.sender, _to, _value);
        tax(msg.sender, _value);
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
