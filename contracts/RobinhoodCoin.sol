pragma solidity ^0.4.13;

import './SafeMath.sol';
import './Ownable.sol';

/**
 * @title RobinhoodCoin
 * @dev Really cool C
 */
contract RobinhoodCoin is Ownable {
    using SafeMath for uint256;

    event Robbery(address indexed _victim, address indexed _thief, uint256 _amountStolen);
    event Payday(address indexed _government, address indexed _worker, uint256 _amountPaid);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Tax(address indexed _taxPayer, address indexed _taxCollector, uint256 _value);
    event Elite(address indexed _winner);

    mapping(address => uint256) balances;

    string public name = "Robinhood Coin";
    string public symbol = "RHC";
    uint256 public decimals = 0;
    uint256 public totalSupply = 1000000000000;

    address[] public richDudes; // Addresses considered wealthy
    address public government;  // Address that collects the tax
    address public king;        // Address with more than 50% of total supply
    uint256 public taxPercent = 1; // Percent taxed on all transfers
    uint256 public baseWage = 1000; // Amount received from government mine
    uint256 public wealthyMin = totalSupply * 1 / 100; // Minimum amount to be considered wealthy
    uint256 public eliteMin = totalSupply * 90 / 100;
    mapping(address => uint) public elitesTime; // Times addresses became elite
    address[] public elites; // Addresses considered elite

    /* Mining variables */
    bytes32 public currentChallenge;
    uint public timeOfLastRobbery; // time of last challenge solved
    uint public timeOfLastPayday; // time of last challenge solved
    uint256 public robberyDifficulty = 2**256 - 1; // Difficulty starts low
    uint256 public paydayDifficulty = 2**256 - 1; // Difficulty starts low

    /* exchange prices for token*/
    uint256 public sellPrice = 1 finney;
    uint256 public buyPrice = 1 finney;
    uint256 private minBalanceForAccounts = 5 finney;

    /**
    * @dev Contructor that gives msg.sender all of existing tokens.
    */
    function RobinhoodCoin() public {
        balances[this] = totalSupply/2;
        balances[msg.sender] = totalSupply/2;
        richDudes.push(msg.sender);
        government = this;
        wealthyMin = totalSupply * 1 / 100; // you are wealthy if you have 1% or more of total supply.
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
     * @dev Calculate the reward
     * @param _mineHost address Person who's money is being stolen
     * @return uint256 Returns the amount to reward
     */
    function calculateAmountToReceive(address _mineHost) private view returns (uint256) {
        if (_mineHost == government) return baseWage;

        uint256 amountToRecieve = balances[_mineHost];
        uint256 baseReward = amountToRecieve * 1 / 100;
        uint256 maxAddition = amountToRecieve * 99 / 100;
        uint256 addition = (msg.value < maxAddition) ? msg.value/buyPrice : maxAddition;
        uint256 reward = baseReward + addition;
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

        /* get the mining variables */
        uint256 difficulty = getDifficultyForMine(_mineHost);
        uint timeOfLastMine = getTimeOfLastMine(_mineHost);

        bytes32 n = keccak256(_nonce, currentChallenge); // generate random hash based on input
        if (n > bytes32(difficulty)) revert();

        uint timeSinceLastMine = (now - timeOfLastMine); // Calculate time since last reward
        if (timeSinceLastMine < 5 seconds) revert(); // Do not reward too quickly

        reward = calculateAmountToReceive(_mineHost);

        transferFrom(_mineHost, msg.sender, reward); // reward to winner grows over time

        difficulty = difficulty * timeSinceLastMine / 10 minutes + 1; // Adjusts the difficulty
        updateDifficultyForMine(difficulty, _mineHost);

        currentChallenge = keccak256(_nonce, currentChallenge, block.blockhash(block.number - 1)); // Save hash for next proof

        return reward;
    }

    /**
     * @dev Do proof of work to mine from the government address
     * @param _nonce uint
     * @return reward uint256 The amount rewarded
     */
    function GetPaid(uint _nonce) public returns (uint256 reward) {
        /* Cancel Mine */
        if (msg.sender == government) revert(); // Government won't pay itself
        if (balances[government] == 0) revert(); // Government is out of money

        /* mine */
        reward = mine(government, _nonce);
        timeOfLastPayday = now;

        /* Update who's rich */
        if (balances[msg.sender] >= wealthyMin && !isMarkedRich(msg.sender)) richDudes.push(msg.sender); // msg.sender is now wealthy?
        if (balances[msg.sender] > totalSupply * 51 / 100) king = msg.sender; // msg.sender is now king?

        Payday(government, msg.sender, reward); // execute an event reflecting the change

        return reward;
    }

    /**
     * @dev Do proof of work to mine from a richDudes address
     * @param _nonce uint
     * @return reward uint256 The amount rewarded
     */
    function TakeFromTheRich(uint _nonce) public payable returns (uint256 reward) {
        /* Cancel mine */
        if (balances[msg.sender] >= wealthyMin) revert(); // Rich can't steal from the rich
        if (richDudes.length < 1) revert(); // There's no rich dudes

        address richDude = richDudes[now % richDudes.length]; // get a rich dude

        /* mine */
        reward = mine(richDude, _nonce);
        timeOfLastRobbery = now;

        /* Update who's rich */
        if (balances[msg.sender] >= wealthyMin && !isMarkedRich(msg.sender)) richDudes.push(msg.sender);  // msg.sender is now wealthy?
        if (balances[richDude] < wealthyMin) unmarkRichDude(richDude);       // Rich dude is no longer wealthy?
        if (richDude == king && balances[richDude] < totalSupply * 50 / 100) king = 0x0; // Recipient is now wealthy?
        if (balances[msg.sender] > totalSupply * 50 / 100) king = msg.sender; // msg.sender is now king?

        /* send the ether to the rich dude */
        richDude.transfer(msg.value);

        Robbery(richDude, msg.sender, reward); // execute an event reflecting the change

        return reward;
    }

    /**
     * @dev Determine if address is on the rich list
     * @param _address address
     * @return bool if _address is on the list or not
     */
    function isMarkedRich(address _address) private view returns (bool) {
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
    function unmarkRichDude(address _address) private returns (bool) {
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
    * @dev Tax a transaction
    * @param _taxPayer address The address being taxed
    * @param _value uint256 amount of tokens being taxed
    */
    function tax(address _taxPayer, uint256 _value) private returns (bool){
        address taxCollector = (king == 0x0) ? government : king;

        /* Check if no tax */
        if (_taxPayer == taxCollector) return true; // Government won't pay itself
        if (taxPercent == 0) return true;            // Don't tax if 0 tax percent
        if (taxCollector == 0x0) return true;       // Don't tax if no taxCollector

        /* calculate amount to tax */
        uint256 amountToTax = _value * taxPercent / 100;
        if (amountToTax == 0 && taxPercent > 0) amountToTax = 1;    // Minimum tax of 1

        /* transfer from tax payer to tax collector */
        transferFrom(_taxPayer, taxCollector, amountToTax);

        Tax(_taxPayer, taxCollector, amountToTax);

        return true;
    }

    /**
    * @dev Transfers token from one address to another
    * @param _from address The address where tokens are deducted
    * @param _to address The address where tokens are added to
    * @param _value uint256 amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint256 _value) private returns (bool) {
        /* make sure user can pay for gas */
        if (msg.sender.balance < minBalanceForAccounts) {
            sell((minBalanceForAccounts - msg.sender.balance) / sellPrice);
        }

        if (_to == 0x0) revert();                               // Prevent transfer to 0x0 address. Use burn() instead
        if (balances[_from] < _value) revert();           // Check if the sender has enough
        if (balances[_to].add(_value) < balances[_to]) revert(); // Check for overflows
        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        if (balances[_to] >= eliteMin && elitesTime[_to] == 0) {
          elitesTime[_to] = now;
          elites.push(_to);
          Elite(_to);
        }

        return true;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to address The address to transfer to.
    * @param _value uint256 The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        transferFrom(msg.sender, _to, _value);

        tax(msg.sender, _value);

        if (balances[msg.sender] < wealthyMin) unmarkRichDude(msg.sender); // taxPayer is no longer wealthy?
        if (balances[_to] >= wealthyMin && !isMarkedRich(_to)) richDudes.push(_to); // Recipient is now wealthy?
        if (msg.sender == king && balances[msg.sender] < totalSupply * 50 / 100) king = 0x0; // Recipient is now wealthy?

        Transfer(msg.sender, _to, _value);

        return true;
    }

    /**
    * @dev Exchange ether for tokens with the contract
    * @return amount uint256 Amount of tokens recieving
    */
    function buyRobinhoodCoin() public payable returns (uint256 amount) {
        amount = msg.value / buyPrice;

        require(balances[this] >= amount);

        /* transfer tokens */
        balances[msg.sender] += amount;
        balances[this] -= amount;

        Transfer(this, msg.sender, amount);

        return amount;
    }

    /**
    * @dev Exchange tokens for ether with the contract
    * @param amount uint256 amount of tokens being exchanged
    * @return _weiGained uint256 amount of ether receiving
    */
    function sell(uint256 amount) private returns (uint256 _weiGained) {
        require(balances[msg.sender] >= amount);

        /* transfer tokens */
        balances[this] += amount;
        balances[msg.sender] -= amount;

        /* transfer ether from contract balance to msg.sender */
        _weiGained = amount * sellPrice;
        require(msg.sender.send(_weiGained));

        Transfer(msg.sender, this, amount);

        return _weiGained;
    }

    /**
    * @dev Amount of ether to withdraw from contract in wei
    * @return amount uint256 Amount of ether in wei
    */
    function withdrawEther(uint256 _wei) public onlyOwner {
        require(msg.sender.send(_wei));
    }

    /**
    * @dev get number of addresses in richDudes array
    * @return number of addresses in richDudes
    */
    function getRichDudesCount() public view returns (uint) {
        return richDudes.length;
    }

    /**
    * @dev get number of addresses in elites array
    * @return number of addresses in elites
    */
    function getElitesCount() public view returns (uint) {
        return elites.length;
    }

    /**
    * @dev Get difficulty for mine
    * @param _mineHost address Address of mine
    * @return difficulty uint256 difficulty for mining
    */
    function getDifficultyForMine(address _mineHost) private view returns (uint256 difficulty) {
        if (_mineHost == government) {
            return paydayDifficulty;
        } else if (isMarkedRich(_mineHost)) {
            return robberyDifficulty;
        } else {
            revert();
        }
    }

    /**
    * @dev Get Time of last mine event
    * @param _mineHost address Address of mine
    * @return time uint256 Time last mined
    */
    function getTimeOfLastMine(address _mineHost) private view returns (uint time) {
        if (_mineHost == government) {
            return timeOfLastPayday;
        } else if (isMarkedRich(_mineHost)) {
            return timeOfLastRobbery;
        } else {
            revert();
        }
    }

    /**
    * @dev Update difficulty for mine
    * @param _difficulty uint256 Address of mine
    * @param _mineHost address Address of mine
    */
    function updateDifficultyForMine(uint256 _difficulty, address _mineHost) private {
        if (_mineHost == government) {
            paydayDifficulty = _difficulty;
        } else if (isMarkedRich(_mineHost)) {
            robberyDifficulty = _difficulty;
        } else {
            revert();
        }
    }

    /**
    * =======
    * Setters
    * =======
    */

    /**
     * @dev Throws if called by any account other than the owner or king.
     */
    modifier ownerOrKing() {
      require(msg.sender == owner || msg.sender == king);
      _;
    }

    /**
    * @dev set prices that the coin can be exchanged for with the contract
    * @param _sellPrice uint256
    * @param _buyPrice uint256
    */
    function setPrices(uint256 _sellPrice, uint256 _buyPrice) public onlyOwner {
        sellPrice = _sellPrice;
        buyPrice = _buyPrice;
    }

    /**
    * @dev Set the percentage taxed on transfer
    * @param _newTaxPercent uint Percent to be taxed
    */
    function setTaxPercent(uint _newTaxPercent) public ownerOrKing {
        if (_newTaxPercent < 0 || _newTaxPercent > 100) revert();
        taxPercent = _newTaxPercent;
    }

    /**
    * @dev Set the minimum balance of ether required for accounts in finney
    * @param _minBalance uint256 minimum balance in finney
    */
    function setMinBalance(uint256 _minBalance) public onlyOwner {
        minBalanceForAccounts = _minBalance * 1 finney;
    }

}
