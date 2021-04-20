// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./YAYAToken.sol";
import "./PAPAToken.sol";
import "./ItemNFT.sol";
import "./ItemHelper.sol";
import "./libs/IMigratorMaster.sol";

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

        // Calculation algorithm is ispired by PancakeSwap, so we kept the name accCakePerShare :)
        // From pancake: We do some fancy math here. Basically, any point in time, the amount of Tokens
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
        address guildMaster; // Guild system leader.
        uint256 guildDeposit; // Guild system balance count.
        uint256 depositToGuild; // Balance contribute to guild.
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
        bool isRandom; // Whether it is random. A random master piece will be a true wonder.
        uint256 template; // Item template for displaying and/or other uses.
        uint256[6] attr; // Attributes of the item. attr = type(32) | value <<32.
    }

    // The ExpToken TOKEN!
    YAYAToken public expToken;
    // The MainToken TOKEN!
    PAPAToken public mainToken;
    // The ItemToken TOKEN!
    ItemNFT public itemToken;

    // Helper functions for items.
    // Defined to reduce contract size and provide certain level of upgradability.
    ItemHelper public itemHelper;

    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorMaster public migrator;
    // Dev address.
    address public devaddr;

    // Exp tokens (PAPA) created per block. 
    // Note: the unit is 1 token, not the min unit which is 1e-18 token
    // The end value should be this * multiplier.
    uint256 public expTokenPerBlock;
    // Main tokens (YAYA) created per block. 
    // Note: the unit is 1 token, not the min unit which is 1e-18 token
    // The end value should be this * multiplier.
    uint256 public mainTokenPerBlock;
    // Multiplier for events or reducing production. Init to 1e18.
    uint256 public EXP_BONUS_MULTIPLIER;
    // Multiplier for events or reducing production. Init to 1e18.
    uint256 public MAIN_BONUS_MULTIPLIER;
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

    // Base NFT price.
    uint256 public RANDOM_NFT_PRICE = 0;
    // Upgrade NFT price.
    uint256 public UPGRADE_NFT_PRICE = 0;

    // Item details: tokenId => details.
    mapping(uint256 => itemDetail) public itemDetails;
    // User profiles.
    mapping(address => UserProfileInfo) public userProfileInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Random state for random function.
    mapping(address => uint256) public randomState;

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
        ItemHelper _itemHelper,
        address _devaddr,
        uint256 _expTokenPerBlock,
        uint256 _mainTokenPerBlock,
        uint256 _startBlock
    ) {
        expToken = _expToken;
        mainToken = _mainToken;
        itemToken = _itemToken;
        itemHelper = _itemHelper;
        devaddr = _devaddr;
        expTokenPerBlock = _expTokenPerBlock;
        mainTokenPerBlock = _mainTokenPerBlock;
        startBlock = _startBlock;

        EXP_BONUS_MULTIPLIER = 10**expToken.decimals();
        MAIN_BONUS_MULTIPLIER = 10**mainToken.decimals();

        totalAllocPointExpToken = 0;
        totalAllocPointMainToken = 0;
    }

    // External functions

    // Update bonus multiplier.
    function updateExpMultiplier(uint256 multiplierNumber) external onlyOwner {
        EXP_BONUS_MULTIPLIER = multiplierNumber;
    }

    // Update bonus multiplier.
    function updateMainMultiplier(uint256 multiplierNumber) external onlyOwner {
        MAIN_BONUS_MULTIPLIER = multiplierNumber;
    }

    // Update max level.
    function updateMaxLevel(uint256 max_level) external onlyOwner {
        MAX_LEVEL = max_level;
    }

    // Update random nft price.
    function updateRandomNftPrice(uint256 price) external onlyOwner {
        RANDOM_NFT_PRICE = price;
    }

    // Update re-roll price.
    function updateUpgradeNftPrice(uint256 price) external onlyOwner {
        UPGRADE_NFT_PRICE = price;
    }

    // Update item drop rates.
    function updateNFTDropRate(
        uint256 inc,
        uint256 base,
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
    function setMigrator(IMigratorMaster _migrator) external onlyOwner {
        migrator = _migrator;
    }

    // Set the itemHelper. Can only be called by the owner.
    function setItemHelper(ItemHelper _itemHelper) external onlyOwner {
        itemHelper = _itemHelper;
    }

    // Manually mint a random NFT
    function mintRandomNFT(address recv) external onlyOwner {
        genRandomNFT(recv, MAX_LEVEL);
    }

    // Manually mint a NFT with given attributes.
    function mintNFT(
        address recv,
        uint256 _level,
        uint256 _template,
        uint256[6] calldata _attr
    ) external onlyOwner {
        uint256 newToken = itemToken.mintNft(recv);
        itemDetail storage detail = itemDetails[newToken];
        detail.template = _template;
        detail.isRandom = false;
        detail.level = _level;
        for (uint256 i = 0; i < 6; i += 1) {
            detail.attr[i] = _attr[i];
        }
    }

    // Equip an item to a slot.
    function equipNFT(
        uint256 _slot,
        uint256 _tokenId
    ) external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        itemDetail storage detail = itemDetails[_tokenId];
        require(_slot < userProfile.invSlotNum && _slot < 6, "invalid slot");

        if (_tokenId == 0) {
            require(_tokenId != userProfile.invSlot[_slot], "already empty");
        } else{
            require(itemToken.ownerOf(_tokenId) == msg.sender, "not item owner");
            require(detail.level <= userProfile.level, "no enough level");
            for (uint8 i = 0; i < 6; i ++) { 
                // case 1: already equipped in other slot.
                // case 2: equip again in same slot for whatever reason.
                // It should always be fine to return here.
                require(_tokenId != userProfile.invSlot[i], "already equipped");
            }
        } 
        userProfile.invSlot[_slot] = _tokenId;
    }

    // User pay exp to levelup.
    function levelUp() external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        uint256 level = userProfile.level;
        uint256 requirement = getLevelUpExp(level);
        if (requirement > 0) {
            uint256 bal = expToken.balanceOf(msg.sender);
            require(bal >= requirement, "No enough balance.");
            expToken.burn(msg.sender, requirement);
        }
        userProfile.level = level.add(1);
    }

    // User pay exp to unlock item .
    function unlockItemSlot() external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        uint256 slotNum = userProfile.invSlotNum;
        require(slotNum < 6, "Maximum slot unlocked.");
        require(userProfile.level >= getUnlockSlotLevelRequirement(slotNum), "No enough level.");
    
        uint256 requiremnt = getUnlockSlotExp(slotNum);
        userProfile.invSlotNum = slotNum.add(1);
        if (requiremnt > 0) {
            uint256 bal = expToken.balanceOf(msg.sender);
            require(bal >= requiremnt, "No enough balance.");
            expToken.burn(msg.sender, requiremnt);
        }
    }

    // Buy random NFT with exp! Set price to 0 to disable!
    function buyRandomNFT() external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        require(RANDOM_NFT_PRICE > 0, "Buying NFT not enabled.");
        uint256 bal = expToken.balanceOf(msg.sender);
        require(bal >= RANDOM_NFT_PRICE, "No enough balance.");

        genRandomNFT(msg.sender, userProfile.level);

        expToken.burn(msg.sender, RANDOM_NFT_PRICE);
    }

    // Reforge NFT!
    function reforgeNFT(
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 tokenId3
    ) external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];

        require(itemToken.ownerOf(tokenId1) == msg.sender, "Not owner!");
        require(itemToken.ownerOf(tokenId2) == msg.sender, "Not owner!");
        require(itemToken.ownerOf(tokenId3) == msg.sender, "Not owner!");

        for (uint8 i = 0; i < 6; i++) {
            if (userProfile.invSlot[i] == 0) {
                continue;
            }
            require(userProfile.invSlot[i] != tokenId1, "Item in use!");
            require(userProfile.invSlot[i] != tokenId2, "Item in use!");
            require(userProfile.invSlot[i] != tokenId3, "Item in use!");
        }

        genRandomNFT(msg.sender, userProfile.level);

        itemToken.burnNft(tokenId1);
        itemToken.burnNft(tokenId2);
        itemToken.burnNft(tokenId3);
    }

    // Re-roll Attribute!
    function upgradeNFT(uint256 tokenId, uint256 index) external {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        require(UPGRADE_NFT_PRICE > 0, "Upgrading NFT not enabled.");
        uint256 bal = expToken.balanceOf(msg.sender);
        require(bal >= UPGRADE_NFT_PRICE, "No enough balance.");

        require(itemToken.ownerOf(tokenId) == msg.sender, "Not owner!");

        for (uint8 i = 0; i < 6; i++) {
            if (userProfile.invSlot[i] == 0) {
                continue;
            }
            require(userProfile.invSlot[i] != tokenId, "Item in use!");
        }

        itemDetail storage detail = itemDetails[tokenId];
        require(index < 6, "index out of range!");
        require(detail.attr[index] != 0, "No existing attr!");

        detail.attr[index] = reRollAttr(detail.level, detail.attr[index]);
        // No longer pure random!
        detail.isRandom = false;
        expToken.burn(msg.sender, UPGRADE_NFT_PRICE);
    }

    // External functions that are view

    // Drop rate with modifiers, 5 decimal digit.
    function getNFTDropRate(uint256 _pid) external view returns (uint256) {
        return
            getNFTDropCounter(_pid)
                .mul(calculateMFBonus(_pid).add(100))
                .div(100)
                .mul(1e5)
                .div(NFT_BASE_DROP_RATE_BASE);
    }

    // View function to see pending tokens on frontend.
    function pendingCake(uint256 _pid)
        external
        view
        returns (uint256)
    {
        require(_pid < poolInfo.length, "invalid pid");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 accCakePerShare = pool.accCakePerShare;

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
    function getInventory()
        external
        view
        returns (uint256[6] memory)
    {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        return userProfile.invSlot;
    }

    // Query current level.
    function getLevel() external view returns (uint256) {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        return userProfile.level;
    }

    // Query max slot number.
    function getInvSlotNum() external view returns (uint256) {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
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
        require(_pid < poolInfo.length, "invalid pid");
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

        if (_isExpToken) {
            totalAllocPointExpToken = totalAllocPointExpToken.add(_allocPoint);
        }
        else {
            totalAllocPointMainToken = totalAllocPointMainToken.add(_allocPoint);
        }
        
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
        require(_pid < poolInfo.length, "invalid pid");
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
        require(_pid < poolInfo.length, "invalid pid");
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

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
            // Leave some yaya for dev for events.
            expToken.mint(devaddr, cakeReward.div(10));
            expToken.mint(address(this), cakeReward);
        } else {
            // Main token has a far more restricted eco model, so no mint for dev.
            // mainToken.mint(devaddr, cakeReward.div(10));
            mainToken.mint(address(this), cakeReward);
        }

        pool.accCakePerShare = pool.accCakePerShare.add(
            cakeReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to FishingMaster for token allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(_pid < poolInfo.length, "invalid pid");
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
            .mul((100 + calculateWeightBonus(_pid)))
            .div(100);

        pool.totalWeightedValue = pool.totalWeightedValue.sub(oldWeight).add(
            user.weight
        );

        user.rewardDebt = user.weight.mul(pool.accCakePerShare).div(1e12);

        // Guild 
        guildDeposit(_amount);

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
        require(_pid < poolInfo.length, "invalid pid");
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
            .mul((100 + calculateWeightBonus(_pid)))
            .div(100);

        pool.totalWeightedValue = pool.totalWeightedValue.sub(oldWeight).add(
            user.weight
        );

        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

        // Guild
        guildWithdraw(_amount);

        emit Withdraw(msg.sender, _pid, _amount);
        // NFT
        if (existingDeposit) {
            // Positive balance before action, need roll
            checkNFTDrop(_pid, userProfile.level, false);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(_pid < poolInfo.length, "invalid pid");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function joinGuild(address guildMaster) public {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        require(userProfile.guildMaster == address(0), 'Already in another guild');
        UserProfileInfo storage gmProfile = userProfileInfo[guildMaster];
        if (guildMaster != msg.sender) {  
            require(guildMaster == gmProfile.guildMaster, 'guild not exit');
        }
        userProfile.guildMaster = guildMaster;
        gmProfile.guildDeposit = gmProfile.guildDeposit.add(userProfile.depositToGuild);
    }

    function leaveGuild() public {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        require(userProfile.guildMaster != address(0), 'not in guild');
        UserProfileInfo storage gmProfile = userProfileInfo[userProfile.guildMaster];
        // Do not check if guild is dismissed.
        gmProfile.guildDeposit = gmProfile.guildDeposit.sub(userProfile.depositToGuild);
        userProfile.guildMaster = address(0);
    }

    // Public functions that are view

    // Get Exp comsumption for unlocking slot.
    function getUnlockSlotExp(
        uint256 _currentSlot
    ) public view returns (uint256) {
        if (_currentSlot == 0) {
            return 0;
        }
        else if (_currentSlot == 1) {
            return uint256(2500).mul(10**expToken.decimals());
        }
        else if (_currentSlot == 2) {
            return uint256(3800).mul(10**expToken.decimals());
        }
        else if (_currentSlot == 3) {
            return uint256(5100).mul(10**expToken.decimals());
        }
        else if (_currentSlot == 4) {
            return uint256(15400).mul(10**expToken.decimals());
        }
        else if (_currentSlot == 5) {
            return uint256(40700).mul(10**expToken.decimals());
        }
        // Internal calls should already guarded against slot >= 6 cases.
        // It should be fine to return 0 to external calls (to save some  error handling code) as this is just a view.
        return 0;
    }

    // Get Exp comsumption for unlocking slot.
    function getUnlockSlotLevelRequirement(
        uint256 _currentSlot
    ) public pure returns (uint256) {
        if (_currentSlot == 0) {
            return 0;
        }
        else if (_currentSlot == 1) {
            return 21;
        }
        else if (_currentSlot == 2) {
            return 31;
        }
        else if (_currentSlot == 3) {
            return 41;
        }
        else if (_currentSlot == 4) {
            return 51;
        }
        else if (_currentSlot == 5) {
            return 61;
        }
        // Internal calls should already guarded against slot >= 6 cases.
        // It should be fine to return 0 to external calls (to save some error handling code) as this is just a view.
        return 0;
    }

    // Get Exp comsumption for level up.
    function getLevelUpExp(uint256 _currentLevel)
        public
        view
        returns (uint256)
    {
        if (_currentLevel == 0) {
            return 0;
        }
        return _currentLevel.mul(50).sub(30).mul(10**expToken.decimals());
    }

    // Get Exp comsumption for level up.
    function getGuildBonus()
        public
        view
        returns (uint256)
    {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        // Not in any guild
        if (userProfile.guildMaster == address(0)) {
            return 0;
        }
        UserProfileInfo storage gmProfile = userProfileInfo[userProfile.guildMaster];
        if (gmProfile.guildMaster != userProfile.guildMaster) {
            // GM already leave the guild.
            return 0;
        }
        uint256 bonus = 0;
        // TODO: Change this number!
        if (gmProfile.guildDeposit > 1000000) {
            bonus = 20;
        } else if (gmProfile.guildDeposit > 100000) {
            bonus = 10;
        }
        if (bonus > 0 && userProfile.guildMaster == msg.sender) {
            bonus = bonus + 5;
        }
        return bonus;
    }

    // Calculate bonus from level and items. Returns percentage.
    function calculateWeightBonus(uint256 _pid)
        public
        view
        returns (uint256)
    {
        require(_pid < poolInfo.length, "invalid pid");
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 itemBonus = 100;
        uint256 guildBonus = 100;

        if (userProfile.invSlotNum <= 6) {
            for (uint8 i = 0; i < userProfile.invSlotNum; i++) {
                if (
                    userProfile.invSlot[i] > 0 &&
                    itemToken.ownerOf(userProfile.invSlot[i]) == msg.sender
                ) {
                    itemDetail storage detail =
                        itemDetails[userProfile.invSlot[i]];
                    if (detail.level > userProfile.level) {
                        continue;
                    }
                    if (pool.isExpToken) {
                        for (uint8 j = 0; j < 6; j++) {
                            if (detail.attr[j] == 0) {
                                break;
                            }
                            itemBonus = itemBonus.add(
                                getExpTokenBonus(
                                    detail.attr[j],
                                    userProfile.level,
                                    _pid
                                )
                            );
                        }
                    } else {
                        for (uint8 j = 0; j < 6; j++) {
                            if (detail.attr[j] == 0) {
                                break;
                            }
                            itemBonus = itemBonus.add(
                                getMainTokenBonus(
                                    detail.attr[j],
                                    userProfile.level,
                                    _pid
                                )
                            );
                        }
                    }
                }
            }
        }
        
        if (pool.isExpToken) {
            guildBonus = guildBonus.add(getGuildBonus());
        }
        
        return
            levelToBonus(userProfile.level)
                .add(100)
                .mul(itemBonus)
                .mul(guildBonus)
                .div(10000)
                .sub(100);
    }

    // Get MF bonus
    function calculateMFBonus(uint256 _pid)
        public
        view
        returns (uint256)
    {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        uint256 itemBonus = 0;

        if (userProfile.invSlotNum <= 6) {
            for (uint8 i = 0; i < userProfile.invSlotNum; i++) {
                if (
                    userProfile.invSlot[i] > 0 &&
                    itemToken.ownerOf(userProfile.invSlot[i]) == msg.sender
                ) {
                    itemDetail storage detail =
                        itemDetails[userProfile.invSlot[i]];
                    if (detail.level > userProfile.level) {
                        continue;
                    }
                    for (uint8 j = 0; j < 6; j++) {
                        if (detail.attr[j] == 0) {
                            break;
                        }
                        itemBonus = itemBonus.add(
                            getMFBonus(detail.attr[j], userProfile.level, _pid)
                        );
                    }
                }
            }
        }

        return itemBonus;
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

    function guildDeposit(uint256 amount) internal {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        userProfile.depositToGuild = userProfile.depositToGuild.add(amount);
        if (userProfile.guildMaster == address(0)) {
            return;
        }
        UserProfileInfo storage gmProfile = userProfileInfo[userProfile.guildMaster];
        // change user deposit count even if the master dismissed the guild.
        gmProfile.guildDeposit = gmProfile.guildDeposit.add(amount);
    }

    function guildWithdraw(uint256 amount) internal {
        UserProfileInfo storage userProfile = userProfileInfo[msg.sender];
        userProfile.depositToGuild = userProfile.depositToGuild.sub(amount);
        if (userProfile.guildMaster == address(0)) {
            return;
        }
        UserProfileInfo storage gmProfile = userProfileInfo[userProfile.guildMaster];
        // change user deposit count even if the master dismissed the guild.
        gmProfile.guildDeposit = gmProfile.guildDeposit.sub(amount);
    }

    // Internal functions that are view

    // Get NFT Drop rate counter for now.
    function getNFTDropCounter(uint256 _pid) internal view returns (uint256) {
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

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to,
        bool isExpToken
    ) internal view returns (uint256) {
        return
            _to.sub(_from).mul(
                isExpToken ? EXP_BONUS_MULTIPLIER : MAIN_BONUS_MULTIPLIER
            );
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
        if (totalAllocPoint == 0) {
            return 0;
        }
        uint256 multiplier =
            getMultiplier(lastRewardBlock, block.number, isExpToken);

        return
            multiplier.mul(cakePerBlock).mul(allocPoint).div(totalAllocPoint);
    }

    // Internal functions that are pure

    // Level bonus.
    function levelToBonus(uint256 level) internal pure returns (uint256) {
        return level;
    }

    // Decode attr and check if it has exp token bonus to given pool.
    function getExpTokenBonus(
        uint256 attr,
        uint256 level,
        uint256 pid
    ) internal view returns (uint256) {
        return itemHelper.getExpTokenBonus(attr, level, pid);
    }

    // Decode attr and check if it has main token bonus to given pool.
    function getMainTokenBonus(
        uint256 attr,
        uint256 level,
        uint256 pid
    ) internal view returns (uint256) {
        return itemHelper.getMainTokenBonus(attr, level, pid);
    }

    // Decode attr and check if it has mf bonus to given pool.
    function getMFBonus(
        uint256 attr,
        uint256 level,
        uint256 pid
    ) internal view returns (uint256) {
        return itemHelper.getMFBonus(attr, level, pid);
    }

    // Private functions
    // Mainly for local helper functions

    // Generate a single item via itemHelper
    function genAttr(uint256 level) private returns (uint256) {
        return itemHelper.genAttr(level, msg.sender);
    }

    // Generate a single item via itemHelper
    function reRollAttr(uint256 ilevel, uint256 oldAttr)
        private
        returns (uint256)
    {
        return itemHelper.reRollAttr(ilevel, oldAttr, msg.sender);
    }

    // Generate a random NFT with a given random seed.
    function genRandomNFT(address recv, uint256 userLevel)
        private
        returns (uint256)
    {
        uint256 newToken = itemToken.mintNft(recv);
        itemDetail storage detail = itemDetails[newToken];

        emit MintNFT(recv, newToken);

        // Pure random function version 0
        detail.template = rand(10);
        detail.isRandom = true;
        // We do not plan to change the level logic so we leave it here.
        uint256 minLevel = 0;
        if (userLevel > 10) {
            minLevel = userLevel.sub(10);
        }
        uint256 maxLevel = userLevel.add(10);

        uint256 level = rand(minLevel, maxLevel);
        detail.level = level - (level % 5) + 5;

        // genAttr actually will ask itemHelper to generate attributes.
        for (uint256 i = 0; i < 6; i++) {
            detail.attr[i] = genAttr(detail.level);
            if (rand(256) >= 2) {
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

        if (
            rand(NFT_BASE_DROP_RATE_BASE) <
            getNFTDropCounter(_pid)
                .mul(calculateMFBonus(_pid).add(100))
                .div(100)
        ) {
            userInfo[_pid][msg.sender].lastDropBlock = block.number;
            return genRandomNFT(msg.sender, _userLevel);
        }
        userInfo[_pid][msg.sender].lastDropBlock = block.number;
        return 0;
    }

    // Random mod _mod using helper functions
    function rand(uint256 _mod) private returns (uint256) {
        // Helper will do sanity check.
        return itemHelper.randMod(_mod, msg.sender);
    }

    // Random in [lower, upper] using helper functions
    function rand(uint256 _lower, uint256 _upper) private returns (uint256) {
        // Helper will do sanity check.
        return itemHelper.rand(_lower, _upper, msg.sender);
    }
}
