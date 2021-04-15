// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./YAYAToken.sol";
import "./PAPAToken.sol";
import "./ItemNFT.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy system to new one.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to legacy LP tokens.
    // New system must mint EXACTLY the same amount of LP tokens or
    // else something bad will haitemTokenn. Traditional Swap does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}

// FishingMaster is the master of the PAPAYA Swap. He can make PAPA YAYA and ITemNFT token and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once PAPA is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract FishingMaster is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 weight; // How many weighted LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastDropBlock; // Last block when a item drop check is rolled.

        // Ispired by PancakeSwap, so we kept the name accCakePerShare :)
        // We do some fancy math here. Basically, any point in time, the amount of Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what haitemTokenns:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Global user profile.
    struct UserProfileInfo {
        uint256 level; // Level.
        uint256[6] invSlot; // Inventory slot.
        uint256 invSlotNum; // Max slot number.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        bool isExpToken; // Address of reward token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardBlock; // Last block number that tokens distribution occurs.
        uint256 accCakePerShare; // Accumulated tokens per share, times 1e12. See below.
        uint256 totalWeightedValue; // Total weighted balance of the pool.
    }

    // Item info, maybe it should belongs to the ItemNFT implementation, but we put it here to have more centralized control.
    struct itemDetail {
        uint256 level; // Item level as well as the level requirement.
        uint256 template; // Item template for displaying and/or other uses. 0 for pure random item for now. A random master piece will be a true wonder.
        uint256[6] attr; // Attributes of the item. attr = type(32) | value <<32.
    }

    // The ExpToken TOKEN!
    YAYAToken public expToken;
    // The MainToken TOKEN!
    PAPAToken public mainToken;
    // The ItemToken TOKEN!
    ItemNFT public itemToken;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;
    // Dev address.
    address public devaddr;

    // Exp tokens (PAPA) created per block.
    uint256 public expTokenPerBlock;
    // Main tokens (YAYA) created per block.
    uint256 public mainTokenPerBlock;
    // Bonus muliplier for early fishers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The block number when tokens mining starts.
    uint256 public startBlock;

    // Level cap for now.
    uint256 public MAX_LEVEL = 20;
    // Base NFT drop rate increment per block.
    uint256 public NFT_BASE_DROP_RATE_INC = 2;
    // Base NFT drop rate denominator.
    uint256 public NFT_BASE_DROP_RATE_BASE = 1000000;
    // Base NFT drop rate cap.
    uint256 public NFT_DROP_RATE_CAP = 20000;

    // Item details: tokenId => details.
    mapping(uint256 => itemDetail) public itemDetails;
    // User profiles.
    mapping(address => UserProfileInfo) public userProfileInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPointExpToken = 0;
    uint256 public totalAllocPointMainToken = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event MintNFT(address indexed user, uint256 indexed tokenid);

    constructor(
        YAYAToken _expToken,
        PAPAToken _mainToken,
        ItemNFT _itemToken,
        address _devaddr,
        uint256 _expTokenPerBlock,
        uint256 _mainTokenPerBlock,
        uint256 _startBlock
    ) {
        expToken = _expToken;
        mainToken = _mainToken;
        itemToken = _itemToken;
        devaddr = _devaddr;
        expTokenPerBlock = _expTokenPerBlock;
        mainTokenPerBlock = _mainTokenPerBlock;
        startBlock = _startBlock;

        totalAllocPointExpToken = 0;
        totalAllocPointMainToken = 0;
    }

    // External functions

    // Update bonus multiplier.
    function updateMultiplier(uint256 multiplierNumber) external onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Update max level.
    function updateMaxLevel(uint256 max_level) external onlyOwner {
        MAX_LEVEL = max_level;
    }

    // Update item drop rates.
    function updateNFTDropRate(
        uint256 base,
        uint256 inc,
        uint256 cap
    ) external onlyOwner {
        NFT_BASE_DROP_RATE_INC = inc;
        NFT_BASE_DROP_RATE_BASE = base;
        NFT_DROP_RATE_CAP = cap;
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) external {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) external onlyOwner {
        migrator = _migrator;
    }

    // Manually mint a random NFT
    function mintRandomNFT(address recv) external onlyOwner {
        genRandomNFT(recv, MAX_LEVEL, randomForNFT(0));
    }

    // Manually mint a NFT with given attributes.
    function mintNFT(
        address recv,
        uint256 _level,
        uint256 _template,
        uint256[6] calldata _attr
    ) external onlyOwner {
        require(_template != 0, "do not pretent to be random!");
        uint256 newToken = itemToken.mintNft(recv);
        itemDetail storage detail = itemDetails[newToken];
        detail.template = _template;

        detail.level = _level;
        for (uint256 i = 0; i < 6; i += 1) {
            detail.attr[i] = _attr[i];
        }
    }

    // Equip an item to a slot.
    function equipNFT(
        address _user,
        uint256 _slot,
        uint256 _tokenId
    ) external {
        UserProfileInfo storage userProfile = userProfileInfo[_user];
        itemDetail storage detail = itemDetails[_tokenId];
        if (_slot > userProfile.invSlotNum || _slot > 6) {
            return;
        }
        if (_tokenId == 0) {
            userProfile.invSlot[_slot] = _tokenId;
        } else if (
            _tokenId > 0 &&
            itemToken.checkOwner(_tokenId, _user) &&
            detail.level <= userProfile.level
        ) {
            userProfile.invSlot[_slot] = _tokenId;
        }
    }

    // External functions that are view

    // View function to see pending tokens on frontend.
    function pendingCake(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCakePerShare = pool.accCakePerShare;
        // uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 lpSupply = pool.totalWeightedValue;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 cakeReward =
                calculateReward(
                    pool.isExpToken,
                    pool.allocPoint,
                    pool.lastRewardBlock
                );
            accCakePerShare = accCakePerShare.add(
                cakeReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Query pool size.
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Query user inventory info.
    function getInventory(address _user)
        external
        view
        returns (uint256[6] memory)
    {
        UserProfileInfo storage userProfile = userProfileInfo[_user];
        return userProfile.invSlot;
    }

    // Query current level.
    function getLevel(address _user) external view returns (uint256) {
        UserProfileInfo storage userProfile = userProfileInfo[_user];
        return userProfile.level;
    }

    // Query max slot number.
    function getInvSlotNum(address _user) external view returns (uint256) {
        UserProfileInfo storage userProfile = userProfileInfo[_user];
        return userProfile.invSlotNum;
    }

    // Query NFT attributes.
    function getNFTInfo(uint256 _tokenId)
        external
        view
        returns (itemDetail memory)
    {
        itemDetail storage detail = itemDetails[_tokenId];
        return detail;
    }

    // Public functions

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        bool _isExpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPointExpToken = totalAllocPointExpToken.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                isExpToken: _isExpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCakePerShare: 0,
                totalWeightedValue: 0
            })
        );
    }

    // Update the given pool's token allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        uint256 prevAllocPoint = pool.allocPoint;
        pool.allocPoint = _allocPoint;

        if (prevAllocPoint != _allocPoint) {
            if (pool.isExpToken) {
                totalAllocPointExpToken = totalAllocPointExpToken
                    .sub(prevAllocPoint)
                    .add(_allocPoint);
            } else {
                totalAllocPointMainToken = totalAllocPointMainToken
                    .sub(prevAllocPoint)
                    .add(_allocPoint);
            }
        }
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        //uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 lpSupply = pool.totalWeightedValue;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 cakeReward =
            calculateReward(
                pool.isExpToken,
                pool.allocPoint,
                pool.lastRewardBlock
            );

        if (pool.isExpToken) {
            expToken.mint(devaddr, cakeReward.div(10));
            expToken.mint(address(this), cakeReward);
        } else {
            mainToken.mint(devaddr, cakeReward.div(10));
            mainToken.mint(address(this), cakeReward);
        }

        pool.accCakePerShare = pool.accCakePerShare.add(
            cakeReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to FishingMaster for token allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];

        bool existingDeposit = false;
        bool newDeposit = false;

        updatePool(_pid);

        if (user.weight > 0) {
            existingDeposit = true;
            uint256 pending =
                user.weight.mul(pool.accCakePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeTransfer(_pid, msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);

            newDeposit = true;
        }
        uint256 oldWeight = user.weight;
        user.weight = user
            .amount
            .mul((100 + calculateWeightBonus(address(msg.sender), _pid)))
            .div(100);

        pool.totalWeightedValue = pool.totalWeightedValue.sub(oldWeight).add(
            user.weight
        );

        user.rewardDebt = user.weight.mul(pool.accCakePerShare).div(1e12);

        emit Deposit(msg.sender, _pid, _amount);

        // NFT
        if (existingDeposit) {
            // Positive balance before action, need roll
            checkNFTDrop(_pid, userProfile.level, false);
        } else if (newDeposit) {
            // Zero balance before action but non-zero after, reset counter
            checkNFTDrop(_pid, userProfile.level, true);
        }
    }

    // Withdraw LP tokens from FishingMaster.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        bool existingDeposit = false;

        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        if (user.weight > 0) {
            existingDeposit = true;
            uint256 pending =
                user.weight.mul(pool.accCakePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeTransfer(_pid, msg.sender, pending);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        uint256 oldWeight = user.weight;
        user.weight = user
            .amount
            .mul((100 + calculateWeightBonus(address(msg.sender), _pid)))
            .div(100);

        pool.totalWeightedValue = pool.totalWeightedValue.sub(oldWeight).add(
            user.weight
        );

        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

        emit Withdraw(msg.sender, _pid, _amount);
        // NFT
        if (existingDeposit) {
            // Positive balance before action, need roll
            checkNFTDrop(_pid, userProfile.level, false);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function levelUp() public {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        uint256 level = userProfile.level;
        uint256 requiremnt = getLevelUpExp(level);
        uint256 bal = expToken.balanceOf(msg.sender);
        require(bal >= requiremnt, "No enough balance.");

        userProfile.level = level.add(1);
        expToken.burn(msg.sender, requiremnt);
    }

    // Public functions that are view

    // Get Exp comsumption for level up.
    function getLevelUpExp(uint256 _currentLevel)
        public
        pure
        returns (uint256)
    {
        // TODO: Change this！
        return _currentLevel.mul(50).add(100);
    }

    // Get NFT Drop rate for now.
    function getNFTDropRate(uint256 _pid) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.number > user.lastDropBlock) {
            uint256 rate =
                (block.number - user.lastDropBlock) * NFT_BASE_DROP_RATE_INC;
            if (rate > NFT_DROP_RATE_CAP) {
                rate = NFT_DROP_RATE_CAP;
            }
            return rate;
        }
        return 0;
    }

    // Calculate bonus from level and items. Returns percentage.
    function calculateWeightBonus(address _user, uint256 _pid)
        public
        view
        returns (uint256)
    {
        UserProfileInfo storage userProfile = userProfileInfo[_user];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 itemBonus = 100;

        if (userProfile.invSlotNum <= 6) {
            for (uint8 i = 0; i < userProfile.invSlotNum; i++) {
                if (userProfile.invSlot[i] > 0 && itemToken.checkOwner(userProfile.invSlot[i], _user)) {
                    itemDetail storage detail = itemDetails[userProfile.invSlot[i]];
                    if (detail.level > userProfile.level) {
                        continue;
                    }
                    if (pool.isExpToken) {
                        for (uint8 j = 0; j < 6; j++) {
                            if (detail.attr[j] == 0) {
                                break;
                            }
                            itemBonus = itemBonus
                                .mul(
                                getExpTokenBonus(detail.attr[j], _pid).add(100)
                            )
                                .div(100);
                        }
                    } else {
                        for (uint8 j = 0; j < 6; j++) {
                            if (detail.attr[j] == 0) {
                                break;
                            }
                            itemBonus = itemBonus
                                .mul(
                                getMainTokenBonus(
                                    detail.attr[j],
                                    _pid
                                )
                                    .add(100)
                            )
                                .div(100);
                        }
                    }
                }
            }
        }

        return levelToBonus(userProfile.level).add(100).mul(itemBonus).div(100).sub(100);
    }

    // Internal functions

    // Transfer token according to pool.
    function safeTransfer(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isExpToken) {
            safeExpTokenTransfer(_to, _amount);
        } else {
            safeMainTokenTransfer(_to, _amount);
        }
    }

    // Safe exp token transfer function, just in case if rounding error causes pool to not have enough tokens.
    function safeExpTokenTransfer(address _to, uint256 _amount) internal {
        uint256 cakeBal = expToken.balanceOf(address(this));
        if (_amount > cakeBal) {
            expToken.transfer(_to, cakeBal);
        } else {
            expToken.transfer(_to, _amount);
        }
    }

    // Safe main token transfer function, just in case if rounding error causes pool to not have enough tokens.
    function safeMainTokenTransfer(address _to, uint256 _amount) internal {
        uint256 cakeBal = mainToken.balanceOf(address(this));
        if (_amount > cakeBal) {
            mainToken.transfer(_to, cakeBal);
        } else {
            mainToken.transfer(_to, _amount);
        }
    }

    // Internal functions that are view

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // Calculate pool pending rewards without checking user debt.
    function calculateReward(
        bool isExpToken,
        uint256 allocPoint,
        uint256 lastRewardBlock
    ) internal view returns (uint256) {
        uint256 totalAllocPoint = 0;
        uint256 cakePerBlock = 0;
        if (isExpToken) {
            totalAllocPoint = totalAllocPointExpToken;
            cakePerBlock = expTokenPerBlock;
        } else {
            totalAllocPoint = totalAllocPointMainToken;
            cakePerBlock = mainTokenPerBlock;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock, block.number);

        return
            multiplier.mul(cakePerBlock).mul(allocPoint).div(totalAllocPoint);
    }

    // Internal functions that are pure

    // Level bonus.
    function levelToBonus(uint256 level) internal pure returns (uint256) {
        return level;
    }

    // Decode attr and check if it has exp token bonus to given pool.
    function getExpTokenBonus(uint256 attr, uint256 _pid)
        internal
        pure
        returns (uint256)
    {
        uint256 attr_type = attr % (2**32);

        if (attr_type == 1) {
            // global expToken bonus
            return (attr_type >> 32);
        } else if (attr_type == 4) {
            // expToken bonus on specific pool
            return (attr_type >> 32) == _pid ? (attr_type >> 64) : 0;
        }

        return 0;
    }

    // Decode attr and check if it has main token bonus to given pool.
    function getMainTokenBonus(uint256 attr, uint256 _pid)
        internal
        pure
        returns (uint256)
    {
        uint256 attr_type = attr % (2**32);

        if (attr_type == 2) {
            // global mainToken bonus
            return (attr_type >> 32);
        } else if (attr_type == 5) {
            // mainToken bonus on specific pool
            return (attr_type >> 32) == _pid ? (attr_type >> 64) : 0;
        }

        return 0;
    }

    // Decode attr and check if it has mf bonus to given pool.
    function getMFBonus(uint256 attr, uint256 _pid)
        internal
        pure
        returns (uint256)
    {
        uint256 attr_type = attr % (2**32);

        if (attr_type == 3) {
            // global mf bonus
            return (attr_type >> 32);
        } else if (attr_type == 6) {
            // mf bonus on specific pool
            return (attr_type >> 32) == _pid ? (attr_type >> 64) : 0;
        }
        return 0;
    }

    // Private functions
    // Mainly for local helper functions

    // Generate a single item attr with a given random seed.
    function genAttr(
        uint256 r,
        uint256 level,
        uint256 poolSize
    ) private view returns (uint256) {
        uint256 r1 = randomForNFT(r);
        uint256 attr = (r1 % 6) + 1;
        r1 = randomForNFT(r1);

        uint256 attr_v = (r1 % level) + 1;
        r1 = randomForNFT(r1);
        if (attr == 4 || attr == 5 || attr == 6) {
            if (poolSize == 0) {
                attr = (attr - 3) | (attr_v << 32);
            } else {
                attr = ((r1 % poolSize) << 32) | (attr_v << 64) | attr;
            }
        } else {
            attr = attr | (attr_v << 32);
        }
        return attr;
    }

    // Generate a random NFT with a given random seed.
    function genRandomNFT(
        address recv,
        uint256 userLevel,
        uint256 seed
    ) private returns (uint256) {
        uint256 newToken = itemToken.mintNft(recv);
        itemDetail storage detail = itemDetails[newToken];
        detail.template = 0;

        emit MintNFT(recv, newToken);

        uint256 rand = randomForNFT(seed);
        uint256 minLevel = 0;
        if (userLevel > 10) {
            minLevel = userLevel.sub(10);
        }
        uint256 maxLevel = MAX_LEVEL.add(10);
        uint256 level = 0;
        if (maxLevel > minLevel) {
            level = (rand % (maxLevel - minLevel)).add(minLevel);
        }
        level = level - (level % 5) + 5;

        detail.level = level;

        for (uint256 i = 0; i < 6; i++) {
            detail.attr[i] = genAttr(rand, level, poolInfo.length);
            rand = randomForNFT(rand);
            if (rand % 256 >= 2) {
                break;
            }
        }

        return newToken;
    }

    // Drop roll!
    function checkNFTDrop(
        uint256 _pid,
        uint256 _userLevel,
        bool resetCounter
    ) private returns (uint256) {
        // Reset last block without roll.
        if (resetCounter) {
            userInfo[_pid][msg.sender].lastDropBlock = block.number;
            return 0;
        }

        uint256 rate = getNFTDropRate(_pid);
        userInfo[_pid][msg.sender].lastDropBlock = block.number;
        uint256 r = randomForNFT(0);

        if (r % NFT_BASE_DROP_RATE_BASE < rate) {
            return genRandomNFT(msg.sender, _userLevel, r);
        }
        return 0;
    }

    // PRNG for NFT related functions.
    // We choose not to use an oracle for randomness in the NFT case for the following reasons:
    // The lagest danger of such PRNG is the case that a miner may reject certain result.
    // However, in the current design, a user can always have another roll several hours later.
    // Therefore he will loss gas fee for rejecting a block and gain almost nothing.
    function randomForNFT(uint256 seed) private view returns (uint256) {
        if (seed == 0) {
            return
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.difficulty,
                            block.timestamp,
                            msg.sender
                        )
                    )
                );
        }
        return uint256(keccak256(abi.encodePacked(seed)));
    }
}
