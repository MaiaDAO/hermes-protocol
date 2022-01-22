// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

library Math {
    function max(uint a, uint b) internal pure returns (uint) {
        return a >= b ? a : b;
    }
    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }
}

interface ve {
    function token() external view returns (address);
    function totalSupply() external view returns (uint);
    function create_lock(uint, uint) external returns (uint);
}

interface underlying {
    function approve(address spender, uint value) external returns (bool);
}

contract BaseV1InitialDistribution {
    /*(uint constant lock = 86400 * 7 * 52 * 4;

    ve public immutable _ve;
    minter public immutable _minter;
    address public immutable _token;

    constructor(
      address  __ve,
      address __minter
    ) {
        _token = underlying(ve(__ve).token());
        _ve = ve(__ve);
        _minter = minter(__minter);
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return _token.totalSupply() - _ve.totalSupply();
    }

    // emission calculation is 2% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return weekly * emission / target_base * circulating_supply() / _token.totalSupply();
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return circulating_supply() * tail_emission / tail_base;
    }

    // calculate inflation and adjust ve balances accordingly
    function calculate_growth(uint _minted) public view returns (uint) {
        return _ve.totalSupply() * _minted / _token.totalSupply();
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + week) { // only trigger if new week
            _period = block.timestamp / week * week;
            active_period = _period;
            weekly = weekly_emission();

            _token.mint(address(_ve_dist), calculate_growth(weekly)); // mint inflation for staked users based on their % balance
            _ve_dist.checkpoint_token(); // checkpoint token balance that was just minted in ve_dist
            _ve_dist.checkpoint_total_supply(); // checkpoint supply

            _token.mint(address(this), weekly); // mint weekly emission to gauge proxy (handles voting and distribution)
            _token.approve(address(_gauge_proxy), weekly);
            _gauge_proxy.notifyRewardAmount(weekly);
        }
        return _period;
    }*/

}
