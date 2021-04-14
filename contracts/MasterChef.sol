// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./PPXToken.sol";
import "./PPYToken.sol";
import "./EquipmentNFT.sol";

// import "@nomiclabs/buidler/console.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy PancakeSwap to CakeSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PancakeSwap LP tokens.
    // CakeSwap must mint EXACTLY the same amount of CakeSwap LP tokens or
    // else something bad will happen. Traditional PancakeSwap does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}

// MasterChef is the master of Cake. He can make Cake and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CAKE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 weight; // How many weighted LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastDropBlock;
        //
        // We do some fancy math here. Basically, any point in time, the amount of CAKEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct UserProfileInfo {
        uint256 level; // level
        uint256[6] equipSlot; // equipment slot
        uint256 slotNum;
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken; // Address of LP token contract.
        bool isPPX; // Address of reward token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. CAKEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that CAKEs distribution occurs.
        uint256 accCakePerShare; // Accumulated CAKEs per share, times 1e12. See below.
        uint256 totalWeightedValue;
    }

    // attr = type(32) | value <<32
    struct EquipmentDetail {
        uint256 level; // level requirement
        bool isRandom;
        uint256[6] attr;
    }

    mapping(uint256 => EquipmentDetail) public equipmentDetails;

    // The PPX TOKEN!
    PPXToken public ppx;
    // The PPY TOKEN!
    PPYToken public ppy;
    // The PPE TOKEN!
    EquipmentNFT public ppe;
    // Dev address.
    address public devaddr;
    // CAKE tokens created per block.
    uint256 public ppxPerBlock;
    uint256 public ppyPerBlock;
    // Bonus muliplier for early cake makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserProfileInfo) public userProfileInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPointPPX = 0;
    uint256 public totalAllocPointPPY = 0;
    // The block number when CAKE mining starts.
    uint256 public startBlock;

    uint256 public NFT_BASE_DROP_RATE_INC = 2;
    uint256 public NFT_BASE_DROP_RATE_BASE = 1000000;
    uint256 public NFT_DROP_RATE_CAP = 20000;
    uint256 public NFT_MAX_LEVEL = 20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    event MintNFT(address indexed user, uint256 indexed tokenid);
    event GenNFTAttr(uint256 attr);

    constructor(
        PPXToken _ppx,
        PPYToken _ppy,
        EquipmentNFT _ppe,
        address _devaddr,
        uint256 _cakePerBlock,
        uint256 _startBlock
    ) {
        ppx = _ppx;
        ppy = _ppy;
        ppe = _ppe;
        devaddr = _devaddr;
        ppxPerBlock = _cakePerBlock;
        ppyPerBlock = _cakePerBlock;
        startBlock = _startBlock;

        totalAllocPointPPX = 0;
        totalAllocPointPPY = 0;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function updateNFTDropRate(
        uint256 base,
        uint256 inc,
        uint256 cap
    ) public onlyOwner {
        NFT_BASE_DROP_RATE_INC = inc;
        NFT_BASE_DROP_RATE_BASE = base;
        NFT_DROP_RATE_CAP = cap;
    }

    function getNFTDropRate(uint256 _pid) public view returns (uint256) {
        if (block.number > userInfo[_pid][msg.sender].lastDropBlock) {
            uint256 rate =
                (block.number - userInfo[_pid][msg.sender].lastDropBlock) *
                    NFT_BASE_DROP_RATE_INC;
            if (rate > NFT_DROP_RATE_CAP) {
                rate = NFT_DROP_RATE_CAP;
            }
            return rate;
        }
        return 0;
    }

    // The lagest danger of this random method is a miner may reject certain result.
    // Since we can always have another nft drop test several hours later,
    // this rejection will not worth the cost of rejecting a block.
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

    function mintRandomNFT(address recv) public onlyOwner returns (uint256) {
        return genRandomNFT(recv, randomForNFT(0));
    }

    function mintNFT(
        address recv,
        uint256 _level,
        uint256[6] calldata _attr
    ) public onlyOwner returns (uint256) {
        uint256 newToken = ppe.mintNft(recv);
        EquipmentDetail storage detail = equipmentDetails[newToken];
        detail.isRandom = false;

        detail.level = _level;
        for (uint256 i = 0; i < 6; i += 1) {
            detail.attr[i] = _attr[i];
        }
        return newToken;
    }

    function genAttr(
        uint256 r,
        uint256 level,
        uint256 poolSize
    ) internal returns (uint256) {
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
        emit GenNFTAttr(attr);
        return attr;
    }

    function genRandomNFT(address recv, uint256 r) internal returns (uint256) {
        uint256 newToken = ppe.mintNft(recv);
        EquipmentDetail storage detail = equipmentDetails[newToken];
        detail.isRandom = true;

        emit MintNFT(recv, newToken);

        uint256 r1 = randomForNFT(r);

        uint256 level = (r1 % 20) + (NFT_MAX_LEVEL.sub(10));
        level = level - (level % 5) + 5;
        detail.level = level;

        for (uint256 i = 0; i < 6; i++) {
            detail.attr[i] = genAttr(r1, level, poolInfo.length);
            r1 = randomForNFT(r1);
            if (r1 % 256 >= 2) {
                break;
            }
        }

        return newToken;
    }

    function checkNFTDrop(uint256 _pid) internal {
        uint256 rate = getNFTDropRate(_pid);
        userInfo[_pid][msg.sender].lastDropBlock = block.number;

        uint256 r = randomForNFT(0);

        if (r % NFT_BASE_DROP_RATE_BASE < rate) {
            genRandomNFT(msg.sender, r);
        }
        return;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IBEP20 _lpToken,
        bool _isPPX,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPointPPX = totalAllocPointPPX.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                isPPX: _isPPX,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCakePerShare: 0,
                totalWeightedValue: 0
            })
        );
    }

    // Update the given pool's CAKE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        if (prevAllocPoint != _allocPoint) {
            if (poolInfo[_pid].isPPX) {
                totalAllocPointPPX = totalAllocPointPPX.sub(prevAllocPoint).add(
                    _allocPoint
                );
            } else {
                totalAllocPointPPY = totalAllocPointPPY.sub(prevAllocPoint).add(
                    _allocPoint
                );
            }
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

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

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function calculateReward(
        bool isPPX,
        uint256 allocPoint,
        uint256 lastRewardBlock
    ) internal view returns (uint256) {
        uint256 totalAllocPoint = 0;
        uint256 cakePerBlock = 0;
        if (isPPX) {
            totalAllocPoint = totalAllocPointPPX;
            cakePerBlock = ppxPerBlock;
        } else {
            totalAllocPoint = totalAllocPointPPY;
            cakePerBlock = ppyPerBlock;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock, block.number);

        return
            multiplier.mul(cakePerBlock).mul(allocPoint).div(totalAllocPoint);
    }

    // View function to see pending CAKEs on frontend.
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
                    pool.isPPX,
                    pool.allocPoint,
                    pool.lastRewardBlock
                );
            accCakePerShare = accCakePerShare.add(
                cakeReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
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
            calculateReward(pool.isPPX, pool.allocPoint, pool.lastRewardBlock);

        if (poolInfo[_pid].isPPX) {
            ppx.mint(devaddr, cakeReward.div(10));
            ppx.mint(address(this), cakeReward);
        } else {
            ppy.mint(devaddr, cakeReward.div(10));
            ppy.mint(address(this), cakeReward);
        }

        pool.accCakePerShare = pool.accCakePerShare.add(
            cakeReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for CAKE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.weight > 0) {
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

        // NFT
        checkNFTDrop(_pid);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accCakePerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeTransfer(_pid, msg.sender, pending);
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

        // NFT
        checkNFTDrop(_pid);

        emit Withdraw(msg.sender, _pid, _amount);
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

    function safeTransfer(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        if (poolInfo[_pid].isPPX) {
            safePPXTransfer(_to, _amount);
        } else {
            safePPYTransfer(_to, _amount);
        }
    }

    // Safe cake transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safePPXTransfer(address _to, uint256 _amount) internal {
        uint256 cakeBal = ppx.balanceOf(address(this));
        if (_amount > cakeBal) {
            ppx.transfer(_to, cakeBal);
        } else {
            ppx.transfer(_to, _amount);
        }
    }

    function safePPYTransfer(address _to, uint256 _amount) internal {
        uint256 cakeBal = ppy.balanceOf(address(this));
        if (_amount > cakeBal) {
            ppy.transfer(_to, cakeBal);
        } else {
            ppy.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function enoughLevel(uint256 level, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        if (equipmentDetails[tokenId].level <= level) {
            return true;
        }
        return false;
    }

    function levelToBonus(uint256 level) internal pure returns (uint256) {
        return level;
    }

    function getPPXBonus(uint256 attr, uint256 _pid)
        internal
        pure
        returns (uint256)
    {
        uint256 attr_type = attr % (2**32);

        if (attr_type == 1) {
            // global ppx bonus
            return (attr_type >> 32);
        } else if (attr_type == 4) {
            // ppx bonus on specific pool
            return (attr_type >> 32) == _pid ? (attr_type >> 64) : 0;
        }

        return 0;
    }

    function getPPYBonus(uint256 attr, uint256 _pid)
        internal
        pure
        returns (uint256)
    {
        uint256 attr_type = attr % (2**32);

        if (attr_type == 2) {
            // global ppy bonus
            return (attr_type >> 32);
        } else if (attr_type == 5) {
            // ppy bonus on specific pool
            return (attr_type >> 32) == _pid ? (attr_type >> 64) : 0;
        }

        return 0;
    }

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

    function calculateWeightBonus(address _user, uint256 _pid)
        public
        view
        returns (uint256)
    {
        uint256 levelBonus =
            levelToBonus(userProfileInfo[_user].level).add(100);
        uint256 equipBonus = 100;

        bool isPPX = poolInfo[_pid].isPPX;

        if (userProfileInfo[_user].slotNum <= 6) {
            for (uint256 i = 0; i < userProfileInfo[_user].slotNum; i++) {
                uint256 nft = userProfileInfo[_user].equipSlot[i];
                if (
                    nft > 0 &&
                    ppe.checkOwner(nft, _user) &&
                    equipmentDetails[nft].level <= userProfileInfo[_user].level
                ) {
                    if (isPPX) {
                        for (uint256 j = 0; j < 6; j++) {
                            if (equipmentDetails[nft].attr[j] == 0) {
                                break;
                            }
                            equipBonus = equipBonus
                                .mul(
                                getPPXBonus(equipmentDetails[nft].attr[j], _pid)
                                    .add(100)
                            )
                                .div(100);
                        }
                    }
                } else {
                    for (uint256 j = 0; j < 6; j++) {
                        if (equipmentDetails[nft].attr[j] == 0) {
                            break;
                        }
                        equipBonus = equipBonus
                            .mul(
                            getPPYBonus(equipmentDetails[nft].attr[j], _pid)
                                .add(100)
                        )
                            .div(100);
                    }
                }
            }
        }

        return levelBonus.mul(equipBonus).div(100).sub(100);
    }

    function equipNFT(
        address _user,
        uint256 _slot,
        uint256 _tokenId
    ) public {
        if (_slot > userProfileInfo[_user].slotNum || _slot > 6) {
            return;
        }
        if (_tokenId == 0) {
            userProfileInfo[_user].equipSlot[_slot] = _tokenId;
        } else if (
            _tokenId > 0 &&
            ppe.checkOwner(_tokenId, _user) &&
            equipmentDetails[_tokenId].level <= userProfileInfo[_user].level
        ) {
            userProfileInfo[_user].equipSlot[_slot] = _tokenId;
        }
    }

    function getLevel(address _user) public view returns (uint256) {
        return userProfileInfo[_user].level;
    }

    function getEquip(address _user) public view returns (uint256[6] memory) {
        return userProfileInfo[_user].equipSlot;
    }

    function getSlotNum(address _user) public view returns (uint256) {
        return userProfileInfo[_user].slotNum;
    }

    function getNFTInfo(uint256 _tokenId)
        public
        view
        returns (EquipmentDetail memory)
    {
        return equipmentDetails[_tokenId];
    }
}
