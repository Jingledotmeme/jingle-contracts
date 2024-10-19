//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./lib/PoolAddress.sol";

contract JingleToken is ERC20, ERC20Capped, Ownable {
    address public swapQuoter;
    address public poolAddress; // immutable
    bool public canAddLiquidity;
    address public liquidityHolder;
    
    uint256 public mintAmount;
    uint256 public buybackInterval;
    uint256 public buybackRatio;
    uint256 public nextBuybackTime;

    modifier onlyLiquidityHolder() {
        require(msg.sender == liquidityHolder, "Not liquidity holder");
        _;
    }
    
    constructor(
        string memory symbol,
        uint256 maxSupply,
        uint256 mintAmount_,
        uint256 buybackInterval_,
        uint256 buybackRatio_,
        address weth,
        address swapFactory,
        address swapQuoter_,
        address liquidityHolder_
    ) ERC20(symbol, symbol) ERC20Capped(maxSupply) {
        require(maxSupply > mintAmount_ && mintAmount_ > 0 && maxSupply % mintAmount_ == 0, "Params error");
        mintAmount = mintAmount_;
        buybackInterval = buybackInterval_;
        buybackRatio = buybackRatio_;
        swapQuoter = swapQuoter_;
        poolAddress = PoolAddress.computeAddress(swapFactory, PoolAddress.getPoolKey(address(this), weth, 10000));
        liquidityHolder = liquidityHolder_;
    }

    function allowAddLiquidity() external onlyLiquidityHolder  {
        canAddLiquidity = true;
    }

    function updateNextBuybackTime(bool isFinish) external onlyLiquidityHolder {
        nextBuybackTime = isFinish ? type(uint256).max : block.timestamp + buybackInterval;
    }

    function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal override view {
        if (from == swapQuoter || to == swapQuoter) {
            return;
        }
        if (!canAddLiquidity) {
            require(to != poolAddress, "No listing allowed before mint ends");
        }
        if (nextBuybackTime < block.timestamp || nextBuybackTime - block.timestamp < 60) {
            require(from != poolAddress, "No purchases allowed one minute before buyback");
        }
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }

    function mint(address receiver, uint256 amount) external onlyOwner {
        require(amount > 0 && amount % mintAmount == 0, "Amount error");
        _mint(receiver, amount);
    }

    function isJingle() external pure returns (bool) {
        return true;
    }

}
