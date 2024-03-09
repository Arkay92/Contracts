// SPDX-License-Identifier: MIT
/* Contract Designed By Robert McMenemy */

pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract ERC20Example is ERC20, Ownable, ReentrancyGuard {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    struct FeeStructure {
        uint256 totalFees;
        uint256 teamFee;
        uint256 liquidityFee;
        uint256 operationalFee;
    }
    struct TokenAllocation {
        uint256 forTeam;
        uint256 forLiquidity;
        uint256 forOperations;
    }
    struct Config {
        address teamWallet;
        address operationalWallet;
        uint256 maxTransactionAmount;
        uint256 swapTokensAtAmount;
        uint256 maxWallet;
    }
    struct StateFlags {
        bool swapping;
        bool limitsInEffect;
        bool tradingActive;
        bool swapEnabled;
    }
    struct AddressFlags {
        bool isExcludedFromFees;
        bool isExcludedFromMaxTransactionAmount;
        bool isAutomatedMarketMakerPair;
    }
    struct LiquidityParameters {
        uint256 maxLiquidityAdditionPercentage; // Max percentage of the contract's token balance that can be used for liquidity in a single transaction
        uint256 liquidityAdditionThreshold; // Minimum token balance in the contract before triggering liquidity addition
    }

    LiquidityParameters public liquidityParams;
    Config public config;
    StateFlags private stateFlags;
    TokenAllocation public tokensAllocated;
    FeeStructure public buyFees;
    FeeStructure public sellFees;

    // Use a single mapping to hold the flags for each address
    mapping(address => AddressFlags) private addressFlags;

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event teamWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event operationalWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    constructor(address _teamWallet, address _v2Router, address _operationalWallet) ERC20("ERC20Example", "ERC20E") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_v2Router);

        // Setting up Uniswap router and pair
        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        // Initialize buy fees
        buyFees = FeeStructure({
            totalFees: 50, // 3% team + 1% liquidity + 1% operational
            teamFee: 30, // 3%
            liquidityFee: 10, // 1%
            operationalFee: 10 // 1%
        });

        // Initialize sell fees
        sellFees = FeeStructure({
            totalFees: 100, // 5% team + 2.5% liquidity + 2.5% operational
            teamFee: 50, // 5%
            liquidityFee: 25, // 2.5%
            operationalFee: 25 // 2.5%
        });

        uint256 totalSupply =  100_000_000 * 1e18; // 100 million

        config = Config({
            teamWallet: _teamWallet,
            operationalWallet: _operationalWallet,
            maxTransactionAmount: 100_000_000 * 1e18 / 100, // 1% of total supply
            swapTokensAtAmount: 100_000_000 * 1e18 * 5 / 100_000, // 0.005% of total supply
            maxWallet: 100_000_000 * 1e18 / 100 // 1% of total supply
        });

        stateFlags = StateFlags({
            swapping: false,
            limitsInEffect: true,
            tradingActive: true,
            swapEnabled: true
        });

        // Exclusions from fees and max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        // Minting the total supply to the owner
        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    function updateLiquidityParameters(uint256 _maxPercentage, uint256 _threshold) external onlyOwner {
        require(_maxPercentage <= 100, "Max percentage must not exceed 100");
        liquidityParams.maxLiquidityAdditionPercentage = _maxPercentage;
        liquidityParams.liquidityAdditionThreshold = _threshold;
    }
        
    function enableTrading() external onlyOwner {
        stateFlags.tradingActive = true;
        stateFlags.swapEnabled = true;
    }
   
    function disableTrading() external onlyOwner {
        stateFlags.tradingActive = false;
        stateFlags.swapEnabled = false;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        stateFlags.limitsInEffect = false;
        return true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool) {
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 5) / 1000, "Swap amount cannot be higher than 0.5% total supply.");
        config.swapTokensAtAmount = newAmount;
        return true;
    }

    function updateMaxTxnAmount(uint256 newNum) external onlyOwner {
        require(newNum >= ((totalSupply() * 5) / 1000) / 1e18, "Cannot set maxTransactionAmount lower than 0.5%");
        config.maxTransactionAmount = newNum * (10 ** 18);
    }

    function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
        require(newNum >= ((totalSupply() * 10) / 1000) / 1e18, "Cannot set maxWallet lower than 1.0%");
        config.maxWallet = newNum * (10 ** 18);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        addressFlags[updAds].isExcludedFromMaxTransactionAmount = isEx;
    }

    // only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        stateFlags.swapEnabled = enabled;
    }

    function updateBuyFees(uint256 _teamFee, uint256 _liquidityFee, uint256 _operationalFee) external onlyOwner {
        buyFees.teamFee = _teamFee;
        buyFees.liquidityFee =_liquidityFee;
        buyFees.operationalFee = _operationalFee;
        buyFees.totalFees = buyFees.teamFee + buyFees.liquidityFee + buyFees.operationalFee;
        require(buyFees.totalFees <= 50, "Buy fees must be <= 5%");
    }

    function updateSellFees(uint256 _teamFee, uint256 _liquidityFee, uint256 _operationalFee) external onlyOwner {
        sellFees.teamFee = _teamFee;
        sellFees.liquidityFee = _liquidityFee;
        sellFees.operationalFee = _operationalFee;
        sellFees.totalFees = sellFees.teamFee + sellFees.liquidityFee + sellFees.operationalFee;
        require(sellFees.totalFees <= 100, "Sell fees must be <= 10%");
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        addressFlags[account].isExcludedFromFees = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from ");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        addressFlags[pair].isAutomatedMarketMakerPair = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateTeamWallet(address newTeamWallet) external onlyOwner {
        emit teamWalletUpdated(newTeamWallet, config.teamWallet);
        config.teamWallet = newTeamWallet;
    }

    function updateOperationalWallet(address newWallet) external onlyOwner {
        emit operationalWalletUpdated(newWallet, config.operationalWallet);
        config.operationalWallet = newWallet;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return addressFlags[account].isExcludedFromFees;
    }

    // Function to update the buy fee structure
    function updateBuyFeeStructure(uint256 _teamFee, uint256 _liquidityFee, uint256 _operationalFee) external onlyOwner {
        require(_teamFee + _liquidityFee + _operationalFee <= 100, "Total fee is over 10%");
        buyFees.teamFee = _teamFee;
        buyFees.liquidityFee = _liquidityFee;
        buyFees.operationalFee = _operationalFee;
        buyFees.totalFees = _teamFee + _liquidityFee + _operationalFee;
    }

    // Function to update the sell fee structure
    function updateSellFeeStructure(uint256 _teamFee, uint256 _liquidityFee, uint256 _operationalFee) external onlyOwner {
        require(_teamFee + _liquidityFee + _operationalFee <= 100, "Total fee is over 10%");
        sellFees.teamFee = _teamFee;
        sellFees.liquidityFee = _liquidityFee;
        sellFees.operationalFee = _operationalFee;
        sellFees.totalFees = _teamFee + _liquidityFee + _operationalFee;
    }

    function _transfer(address from, address to, uint256 amount) internal override nonReentrant {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (stateFlags.limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !stateFlags.swapping
            ) {
                if (!stateFlags.tradingActive) {
                    require(addressFlags[from].isExcludedFromFees || addressFlags[to].isExcludedFromFees, "Trading is not active.");
                }

                //when buy
                if (
                    addressFlags[from].isAutomatedMarketMakerPair &&
                    !addressFlags[to].isExcludedFromMaxTransactionAmount
                ) {
                    require(amount <= config.maxTransactionAmount,"Buy transfer amount exceeds the maxTransactionAmount.");
                    require(amount + balanceOf(to) <= config.maxWallet,"Max wallet exceeded");
                }
                //when sell
                else if (
                    addressFlags[to].isAutomatedMarketMakerPair &&
                    !addressFlags[from].isExcludedFromMaxTransactionAmount
                ) {
                    require(amount <= config.maxTransactionAmount,"Sell transfer amount exceeds the maxTransactionAmount.");
                } else if (!addressFlags[to].isExcludedFromMaxTransactionAmount) {
                    require(amount + balanceOf(to) <= config.maxWallet,"Max wallet exceeded");
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= config.swapTokensAtAmount;
       
        if (
            canSwap &&
            stateFlags.swapEnabled &&
            !stateFlags.swapping &&
            !addressFlags[from].isAutomatedMarketMakerPair &&
            !addressFlags[from].isExcludedFromFees &&
            !addressFlags[to].isExcludedFromFees
        ) {
            stateFlags.swapping = true;

            swapBack();

            stateFlags.swapping = false;
        }

        bool takeFee = !stateFlags.swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (addressFlags[from].isExcludedFromFees || addressFlags[to].isExcludedFromFees) {
            takeFee = false;
        }

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (addressFlags[to].isAutomatedMarketMakerPair && sellFees.totalFees > 0) {
                fees = (amount * sellFees.totalFees) / 1000;
                tokensAllocated.forLiquidity += (fees * sellFees.liquidityFee) / sellFees.totalFees;
                tokensAllocated.forOperations += (fees * sellFees.operationalFee) / sellFees.totalFees;
                tokensAllocated.forTeam += (fees * sellFees.teamFee) / sellFees.totalFees;
            }

            // on buy
            if (addressFlags[from].isAutomatedMarketMakerPair && buyFees.totalFees > 0) {
                fees = (amount * buyFees.totalFees) / 1000;
                tokensAllocated.forLiquidity += (fees * buyFees.liquidityFee) / buyFees.totalFees;
                tokensAllocated.forOperations += (fees * buyFees.operationalFee) / buyFees.totalFees;
                tokensAllocated.forTeam += (fees * buyFees.teamFee) / buyFees.totalFees;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private nonReentrant {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private nonReentrant {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function swapBack() private nonReentrant {
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= liquidityParams.liquidityAdditionThreshold;
        if (overMinTokenBalance && stateFlags.swapEnabled && !stateFlags.swapping) {
            uint256 liquidityAmount = contractTokenBalance * liquidityParams.maxLiquidityAdditionPercentage / 100;
            // Ensure liquidity amount does not exceed the set threshold
            liquidityAmount = (liquidityAmount > liquidityParams.liquidityAdditionThreshold) ? liquidityParams.liquidityAdditionThreshold : liquidityAmount;

            // Split the liquidity token amount into halves
            uint256 half = liquidityAmount / 2;
            uint256 otherHalf = liquidityAmount - half;

            // Capture the contract's current ETH balance.
            uint256 initialBalance = address(this).balance;

            // Swap tokens for ETH
            swapTokensForEth(half); 

            // How much ETH did we just swap into?
            uint256 newBalance = address(this).balance - initialBalance;

            // Add liquidity to Uniswap
            addLiquidity(otherHalf, newBalance);
            
            emit SwapAndLiquify(half, newBalance, otherHalf);
        }
    }

    function withdrawStuckAssets(address _token, address _to) external onlyOwner {
        require(_to != address(0), "Withdraw: to address cannot be 0");

        if (_token == address(0)) { // Withdraw native currency (e.g., ETH)
            uint256 balance = address(this).balance;
            (bool success, ) = _to.call{value: balance}("");
            require(success, "Withdraw: Failed to send ETH");
        } else if (_token == address(this)) { // Withdraw contract's own tokens
            uint256 balance = balanceOf(address(this));
            _transfer(address(this), _to, balance);
        } else { // Withdraw any other ERC20 tokens
            uint256 balance = IERC20(_token).balanceOf(address(this));
            require(IERC20(_token).transfer(_to, balance), "Withdraw: Failed to transfer ERC20 tokens");
        }
    }
}
