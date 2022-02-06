// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

library Math {
    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }
}

interface erc20 {
    function totalSupply() external view returns (uint256);
    function transfer(address recipient, uint amount) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
}

interface ve {
    function token() external view returns (address);
    function balanceOfNFT(uint) external view returns (uint);
    function isApprovedOrOwner(address, uint) external view returns (bool);
    function ownerOf(uint) external view returns (address);
    function transferFrom(address, address, uint) external;
    function attach(uint tokenId) external;
    function detach(uint tokenId) external;
    function voting(uint tokenId) external;
    function abstain(uint tokenId) external;
}

interface IBaseV1Factory {
    function isPair(address) external view returns (bool);
}

interface IBaseV1Core {
    function claimFees() external returns (uint, uint);
    function tokens() external returns (address, address);
}

interface IBaseV1GaugeFactory {
    function createGauge(address, address, address) external returns (address);
}

interface IBaseV1BribeFactory {
    function createBribe() external returns (address);
}

interface IGauge {
    function notifyRewardAmount(address token, uint amount) external;
    function getReward(address account, address[] memory tokens) external;
    function claimFees() external returns (uint claimed0, uint claimed1);
    function left(address token) external view returns (uint);
}

interface IBribe {
    function _deposit(uint amount, uint tokenId) external;
    function _withdraw(uint amount, uint tokenId) external;
    function getRewardForOwner(uint tokenId, address[] memory tokens) external;
}

contract BaseV1Voter {

    address public immutable _ve; // the ve token that governs these contracts
    address public immutable factory; // the BaseV1Factory
    address internal immutable base;
    address public immutable gaugefactory;
    address public immutable bribefactory;
    address public minter;

    uint public totalWeight; // total voting weight

    address[] public pools; // all pools viable for incentives
    mapping(address => address) public gauges; // pool => gauge
    mapping(address => address) public poolForGauge; // gauge => pool
    mapping(address => address) public bribes; // gauge => bribe
    mapping(address => uint) public forWeights; // pool => weight
    mapping(address => uint) public againstWeights; // pool => weight
    mapping(uint => mapping(address => uint)) public forVotes; // nft => pool => votes
    mapping(uint => mapping(address => uint)) public againstVotes; // nft => pool => votes
    mapping(uint => address[]) public forPoolVote; // nft => pools
    mapping(uint => address[]) public againstPoolVote; // nft => pools
    mapping(uint => uint) public usedWeights;  // nft => total voting weight of user
    mapping(address => bool) public isGauge;
    mapping(address => bool) public isWhitelisted;

    event GaugeCreated(address indexed gauge, address creator, address indexed bribe, address indexed pool);
    event VotedFor(address indexed voter, uint tokenId, uint weight);
    event VotedAgainst(address indexed voter, uint tokenId, uint weight);
    event AbstainedAgainst(uint tokenId, uint weight);
    event AbstainedFor(uint tokenId, uint weight);
    event Deposit(address indexed lp, address indexed gauge, uint tokenId, uint amount);
    event Withdraw(address indexed lp, address indexed gauge, uint tokenId, uint amount);
    event NotifyReward(address indexed sender, address indexed reward, uint amount);
    event DistributeReward(address indexed sender, address indexed gauge, uint amount);
    event Attach(address indexed owner, address indexed gauge, uint tokenId);
    event Detach(address indexed owner, address indexed gauge, uint tokenId);

    constructor(address __ve, address _factory, address  _gauges, address _bribes) {
        _ve = __ve;
        factory = _factory;
        base = ve(__ve).token();
        gaugefactory = _gauges;
        bribefactory = _bribes;
        minter = msg.sender;
    }

    // simple re-entrancy check
    uint internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    function initialize(address[] memory _tokens, address _minter) external {
        require(msg.sender == minter);
        for (uint i = 0; i < _tokens.length; i++) {
            _whitelist(_tokens[i]);
        }
        minter = _minter;
    }

    function listing_fee() public view returns (uint) {
        return (erc20(base).totalSupply() - erc20(_ve).totalSupply()) / 200;
    }

    function reset(uint _tokenId) external {
        require(ve(_ve).isApprovedOrOwner(msg.sender, _tokenId));
        _reset(_tokenId);
        ve(_ve).abstain(_tokenId);
    }

    function _reset(uint _tokenId) internal {
        _resetFor(_tokenId);
        _resetAgainst(_tokenId);
        usedWeights[_tokenId] = 0;
    }

    function _resetFor(uint _tokenId) internal {
        address[] storage _poolVote = forPoolVote[_tokenId];
        uint _poolVoteCnt = _poolVote.length;
        uint _totalWeight = 0;

        for (uint i = 0; i < _poolVoteCnt; i++) {
            address _pool = _poolVote[i];
            uint _votes = forVotes[_tokenId][_pool];

            if (_votes > 0) {
                _updateFor(gauges[_pool]);
                _totalWeight += _votes;
                forWeights[_pool] -= _votes;
                forVotes[_tokenId][_pool] -= _votes;
                IBribe(bribes[gauges[_pool]])._withdraw(_votes, _tokenId);
                emit AbstainedFor(_tokenId, _votes);
            }
        }
        totalWeight -= _totalWeight;
        delete forPoolVote[_tokenId];
    }

    function _resetAgainst(uint _tokenId) internal {
        address[] storage _poolVote = againstPoolVote[_tokenId];
        uint _poolVoteCnt = _poolVote.length;
        uint _totalWeight = 0;

        for (uint i = 0; i < _poolVoteCnt; i++) {
            address _pool = _poolVote[i];
            uint _votes = againstVotes[_tokenId][_pool];

            if (_votes > 0) {
                _updateFor(gauges[_pool]);
                _totalWeight += _votes;
                againstWeights[_pool] -= _votes;
                againstVotes[_tokenId][_pool] -= _votes;
                emit AbstainedAgainst(_tokenId, _votes);
            }
        }
        totalWeight -= _totalWeight;
        delete againstPoolVote[_tokenId];
    }

    function poke(uint _tokenId) external {
        address[] memory _forPoolVote = forPoolVote[_tokenId];
        address[] memory _againstPoolVote = againstPoolVote[_tokenId];
        uint _forPoolCnt = _forPoolVote.length;
        uint _againstPoolCnt = _againstPoolVote.length;
        uint _totalCnt = _forPoolCnt + _againstPoolCnt;
        uint[] memory _weights = new uint[](_totalCnt);
        bool[] memory _against = new bool[](_totalCnt);
        address[] memory _poolVote = new address[](_totalCnt);

        uint x = 0;

        for (uint i = 0; i < _forPoolCnt; i++) {
            _against[x] = false;
            _poolVote[x] = _forPoolVote[i];
            _weights[x++] = forVotes[_tokenId][_forPoolVote[i]];
        }

        for (uint i = 0; i < _againstPoolCnt; i++) {
            _against[x] = true;
            _poolVote[x] = _againstPoolVote[i];
            _weights[x++] = againstVotes[_tokenId][_againstPoolVote[i]];
        }

        _vote(_tokenId, _poolVote, _weights, _against);
    }

    function _vote(uint _tokenId, address[] memory _poolVote, uint[] memory _weights, bool[] memory _against) internal {
        _reset(_tokenId);
        uint _poolCnt = _poolVote.length;
        uint _weight = ve(_ve).balanceOfNFT(_tokenId);
        uint _totalVoteWeight = 0;
        uint _totalWeight = 0;
        uint _usedWeight = 0;

        for (uint i = 0; i < _poolCnt; i++) {
            _totalVoteWeight += _weights[i];
        }

        for (uint i = 0; i < _poolCnt; i++) {
            address _pool = _poolVote[i];
            address _gauge = gauges[_pool];
            uint _poolWeight = _weights[i] * _weight / _totalVoteWeight;

            if (isGauge[_gauge]) {
                _updateFor(_gauge);
                _usedWeight += _poolWeight;
                _totalWeight += _poolWeight;
                if (!_against[i]) {
                    forWeights[_pool] += _poolWeight;
                    forPoolVote[_tokenId].push(_pool);

                    forVotes[_tokenId][_pool] += _poolWeight;
                    IBribe(bribes[_gauge])._deposit(_poolWeight, _tokenId);
                    emit VotedFor(msg.sender, _tokenId, _poolWeight);
                } else {
                    againstWeights[_pool] += _poolWeight;
                    againstPoolVote[_tokenId].push(_pool);

                    againstVotes[_tokenId][_pool] += _poolWeight;
                    emit VotedAgainst(msg.sender, _tokenId, _poolWeight);
                }
            }
        }
        if (_usedWeight > 0) ve(_ve).voting(_tokenId);
        totalWeight += _totalWeight;
        usedWeights[_tokenId] = _usedWeight;
    }

    function vote(uint tokenId, address[] calldata _poolVote, uint[] calldata _weights) external {
        require(ve(_ve).isApprovedOrOwner(msg.sender, tokenId));
        require(_poolVote.length == _weights.length);
        _vote(tokenId, _poolVote, _weights, new bool[](_weights.length));
    }

    function voteMixed(uint tokenId, address[] calldata _poolVote, uint[] calldata _weights, bool[] calldata _against) external {
        require(ve(_ve).isApprovedOrOwner(msg.sender, tokenId));
        require(_poolVote.length == _weights.length);
        _vote(tokenId, _poolVote, _weights, _against);
    }

    function whitelist(address _token, uint _tokenId) public {
        if (_tokenId > 0) {
            require(msg.sender == ve(_ve).ownerOf(_tokenId));
            require(ve(_ve).balanceOfNFT(_tokenId) > listing_fee());
        } else {
            _safeTransferFrom(base, msg.sender, minter, listing_fee());
        }

        _whitelist(_token);
    }

    function _whitelist(address _token) internal {
        require(!isWhitelisted[_token]);
        isWhitelisted[_token] = true;
    }

    function createGauge(address _pool) external returns (address) {
        require(gauges[_pool] == address(0x0), "exists");
        require(IBaseV1Factory(factory).isPair(_pool), "!_pool");
        (address tokenA, address tokenB) = IBaseV1Core(_pool).tokens();
        require(isWhitelisted[tokenA] && isWhitelisted[tokenB], "!whitelisted");
        address _bribe = IBaseV1BribeFactory(bribefactory).createBribe();
        address _gauge = IBaseV1GaugeFactory(gaugefactory).createGauge(_pool, _bribe, _ve);
        erc20(base).approve(_gauge, type(uint).max);
        bribes[_gauge] = _bribe;
        gauges[_pool] = _gauge;
        poolForGauge[_gauge] = _pool;
        isGauge[_gauge] = true;
        _updateFor(_gauge);
        pools.push(_pool);
        emit GaugeCreated(_gauge, msg.sender, _bribe, _pool);
        return _gauge;
    }

    function attachTokenToGauge(uint tokenId, address account) external {
        require(isGauge[msg.sender]);
        if (tokenId > 0) ve(_ve).attach(tokenId);
        emit Attach(account, msg.sender, tokenId);
    }

    function emitDeposit(uint tokenId, address account, uint amount) external {
        require(isGauge[msg.sender]);
        emit Deposit(account, msg.sender, tokenId, amount);
    }

    function detachTokenFromGauge(uint tokenId, address account) external {
        require(isGauge[msg.sender]);
        if (tokenId > 0) ve(_ve).detach(tokenId);
        emit Detach(account, msg.sender, tokenId);
    }

    function emitWithdraw(uint tokenId, address account, uint amount) external {
        require(isGauge[msg.sender]);
        emit Withdraw(account, msg.sender, tokenId, amount);
    }

    function length() external view returns (uint) {
        return pools.length;
    }

    uint internal index;
    mapping(address => uint) internal supplyIndex;
    mapping(address => uint) public claimable;

    function notifyRewardAmount(uint amount) external lock {
        _safeTransferFrom(base, msg.sender, address(this), amount); // transfer the distro in
        uint256 _ratio = amount * 1e18 / totalWeight; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index += _ratio;
        }
        emit NotifyReward(msg.sender, base, amount);
    }

    function updateFor(address[] memory _gauges) external {
        for (uint i = 0; i < _gauges.length; i++) {
            _updateFor(_gauges[i]);
        }
    }

    function updateForRange(uint start, uint end) public {
        for (uint i = start; i < end; i++) {
            _updateFor(gauges[pools[i]]);
        }
    }

    function updateAll() external {
        updateForRange(0, pools.length);
    }

    function updateGauge(address _gauge) external {
        _updateFor(_gauge);
    }

    function _updateFor(address _gauge) internal {
        address _pool = poolForGauge[_gauge];
        uint _supplied = forWeights[_pool] - Math.min(forWeights[_pool], againstWeights[_pool]);
        if (_supplied > 0) {
            uint _supplyIndex = supplyIndex[_gauge];
            uint _index = index; // get global index0 for accumulated distro
            supplyIndex[_gauge] = _index; // update _gauge current position to global position
            uint _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta > 0) {
                uint _share = _supplied * _delta / 1e18; // add accrued difference for each supplied token
                claimable[_gauge] += _share;
            }
        } else {
            supplyIndex[_gauge] = index; // new users are set to the default global state
        }
    }

    function claimRewards(address[] memory _gauges, address[][] memory _tokens) external {
        for (uint i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).getReward(msg.sender, _tokens[i]);
        }
    }

    function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint _tokenId) external {
        require(ve(_ve).isApprovedOrOwner(msg.sender, _tokenId));
        for (uint i = 0; i < _bribes.length; i++) {
            IBribe(_bribes[i]).getRewardForOwner(_tokenId, _tokens[i]);
        }
    }

    function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId) external {
        require(ve(_ve).isApprovedOrOwner(msg.sender, _tokenId));
        for (uint i = 0; i < _fees.length; i++) {
            IBribe(_fees[i]).getRewardForOwner(_tokenId, _tokens[i]);
        }
    }

    function distributeFees(address[] memory _gauges) external {
        for (uint i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).claimFees();
        }
    }

    function distribute(address _gauge) public lock {
        _updateFor(_gauge);
        uint _claimable = claimable[_gauge];
        uint _left = IGauge(_gauge).left(base);
        if (_claimable > _left) {
            claimable[_gauge] = 0;
            IGauge(_gauge).notifyRewardAmount(base, _claimable);
            emit DistributeReward(msg.sender, _gauge, _claimable);
        }
    }

    function distro() external {
        distribute(0, pools.length);
    }

    function distribute() external {
        distribute(0, pools.length);
    }

    function distribute(uint start, uint finish) public {
        for (uint x = start; x < finish; x++) {
            distribute(gauges[pools[x]]);
        }
    }

    function distribute(address[] memory _gauges) external {
        for (uint x = 0; x < _gauges.length; x++) {
            distribute(_gauges[x]);
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
