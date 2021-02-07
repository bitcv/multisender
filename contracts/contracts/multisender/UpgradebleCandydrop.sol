// Roman Storm Multi Sender
// To Use this Dapp: https://rstormsf.github.io/multisender
pragma solidity 0.4.23;

import "../OwnedUpgradeabilityStorage.sol";
import "./Claimable.sol";
import "../SafeMath.sol";

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract UpgradebleCandydrop is OwnedUpgradeabilityStorage, Claimable {
    using SafeMath for uint256;
    
    struct Packet {
        address token;
        address owner;
        uint32 packetId;
        uint8 packetType;
        uint256 packetAmount;
        uint8 packetCount;
        uint256 claimCount;
        uint256 remainAmount;
        uint256 remainCount;
        mapping(address => uint256)  receivers;
        address maxAddress;
        address[] bufferAddresses;
        address[] addresses;
    }
    mapping(uint256 => Packet) public packets;
    event Packetstarted(uint256 total, address tokenAddress);
    event Packetended(uint256 total, address tokenAddress);
    event ClaimedTokens(address token, address owner, uint256 balance);

    uint8 PACKET_TYPE_LUCKY = 1;
    uint8 PACKET_TYPE_AVG = 2;

    modifier hasFee() {
        if (currentFee(msg.sender) > 0) {
            require(msg.value >= currentFee(msg.sender));
        }
        _;
    }

    function() public payable {}

    function initialize(address _owner) public {
        require(!initialized());
        setOwner(_owner);
        setArrayLimit(200);
        setDiscountStep(0.00005 ether);
        setFee(0.05 ether);
        boolStorage[keccak256("rs_multisender_initialized")] = true;
    }

    function initialized() public view returns (bool) {
        return boolStorage[keccak256("rs_multisender_initialized")];
    }
 
    function txCount(address customer) public view returns(uint256) {
        return uintStorage[keccak256("txCount", customer)];
    }

    function arrayLimit() public view returns(uint256) {
        return uintStorage[keccak256("arrayLimit")];
    }

    function setArrayLimit(uint256 _newLimit) public onlyOwner {
        require(_newLimit != 0);
        uintStorage[keccak256("arrayLimit")] = _newLimit;
    }

    function discountStep() public view returns(uint256) {
        return uintStorage[keccak256("discountStep")];
    }

    function setDiscountStep(uint256 _newStep) public onlyOwner {
        require(_newStep != 0);
        uintStorage[keccak256("discountStep")] = _newStep;
    }

    function fee() public view returns(uint256) {
        return uintStorage[keccak256("fee")];
    }

    function currentFee(address _customer) public view returns(uint256) {
        if (fee() > discountRate(msg.sender)) {
            return fee().sub(discountRate(_customer));
        } else {
            return 0;
        }
    }

    function setFee(uint256 _newStep) public onlyOwner {
        require(_newStep != 0);
        uintStorage[keccak256("fee")] = _newStep;
    }

    function discountRate(address _customer) public view returns(uint256) {
        uint256 count = txCount(_customer);
        return count.mul(discountStep());
    }
    function randomId(uint256 seed) private view returns (uint32) {
        uint32 packetId = uint32(keccak256(block.timestamp, block.difficulty, seed));
        return packetId;
    }
    function randomSecretId(string secret) private view returns (uint32){
        uint32 packetId = uint32(keccak256(block.timestamp, block.difficulty, secret));
        return packetId;
    }
    function sendPacket(uint32 packetId, address token, uint8 packetType, uint256 packetAmount, uint8 packetCount) private{
        //先存储
        packetsendToken(token, packetAmount);
        
        //保存元数据
        Packet memory packet;
        packet.token = token;
        packet.packetId = packetId;
        packet.packetType = packetType;
        packet.packetAmount = packetAmount;
        packet.packetCount = packetCount;
        packet.remainAmount = packetAmount;
        packet.remainCount = packetCount;
        packet.claimCount = 0;
        packet.owner = msg.sender;
        //  = Packet({
        //      token:token,
        //      packetId:packetId,
        //      packetType:packetType,
        //      packetAmount:packetAmount,
        //      packetCount:packetCount,
        //      remainAmount:packetAmount,
        //      remainCount:packetCount,
        //      bufferAddresses: new address[](address(0x0))
        // });
        packets[packetId] = packet;
    }

    function calcAvgAmount(uint256 remainAmount, uint256 remainCount) private pure returns(uint256) {
        if (remainAmount <= 0 || remainCount <= 0) {
            return 0;
        }
        uint256 myAmount = 0;
        // 只剩一个红包
        if (remainCount == 1) {
            myAmount = remainAmount;
            return myAmount;
        }
        return remainAmount.div(remainCount);
    }

    // 计算抢红包数量
    function calcAmount(uint256 remainAmount, uint256 remainCount) private view returns(uint256) {
        if (remainAmount <= 0 || remainCount <= 0) {
            return 0;
        }
        uint256 myAmount = 0;
        // 只剩一个红包
        if (remainCount == 1) {
            myAmount = remainAmount;
            return myAmount;
        }
        //最小数量为平均值的1/10
        uint256 packetMin = remainAmount.div(remainCount).div(10);
        // 最大数量1: 假设剩余所有人都拿最小数量
        uint256 maxAmount =  remainAmount.sub(remainCount.sub(1).mul(packetMin));
        // 最大数量2: 平均值的两倍
        uint256 avgMaxAmount = remainAmount.div(remainCount).mul(2);
        // 取二者较小的作为最大数量
        uint256 randMax = maxAmount > avgMaxAmount ? avgMaxAmount : maxAmount;
        
        // 获取随机数量
        uint256 upSeed = randMax.div(packetMin);
        myAmount = (uint256(keccak256(block.timestamp, block.difficulty)) % upSeed).mul(packetMin);
        if(myAmount == 0) {
            myAmount = packetMin;
        }
        return myAmount;
    }

    function sendSeedPacket(address token, uint256 seed, uint8 packetType, uint256 packetAmount, uint8 packetCount) public hasFee payable {
        uint32 packetId = randomId(seed); 
        if(packetId < 1000){
            packetId = randomId(seed);
        }
        uintStorage[keccak256("pp", seed)] = packetId; 
        sendPacket(packetId, token, packetType, packetAmount, packetCount);
    }
    function sendSecretPacket(address token, string secret, uint8 packetType, uint256 packetAmount, uint8 packetCount) public hasFee payable {
        uint32 packetId = randomSecretId(secret);
        if(packetId <1000){
            packetId = randomSecretId(secret);
        }
        uintStorage[keccak256("pp", secret)] = packetId; 
        sendPacket(packetId, token, packetType, packetAmount, packetCount);
    }
    function claimPacket(uint32 packetId, bool needDist) private{
        Packet storage packet = packets[packetId];
        require(packet.remainCount > 0, 'no remain left');
        require(packet.receivers[msg.sender]==0, 'only claim once');

        if(packet.remainCount == packet.packetCount){
            packets[packetId].maxAddress = msg.sender;
        }
        uint256 remainAmount = packet.remainAmount;
        uint256 remainCount = packet.remainCount;
        uint256 myAmount = 0;
        if(packet.packetType == PACKET_TYPE_AVG)
        {
            myAmount = calcAvgAmount(remainAmount, remainCount);
        } 
        else{
            myAmount = calcAmount(remainAmount, remainCount);
        } 
        remainAmount = remainAmount.sub(myAmount);
        remainCount = remainCount.sub(1);
        packets[packetId].remainAmount = remainAmount;
        packets[packetId].remainCount = remainCount;
        packets[packetId].claimCount = packets[packetId].claimCount.add(1);
        
        packets[packetId].receivers[msg.sender] = myAmount;
        packets[packetId].bufferAddresses.push(msg.sender);
        packets[packetId].addresses.push(msg.sender);
        if(myAmount > packet.receivers[packet.maxAddress]){
            packets[packetId].maxAddress = msg.sender;
        }
        if(remainCount <= 0 || packets[packetId].bufferAddresses.length > 20 || needDist){
            distributePacket(packetId);
        }
    }
    function distributePacket(uint32 packetId) public{
        uint256 i = 0;
        uint256 len =  packets[packetId].bufferAddresses.length;
        uint256 [] memory balances = new uint256[](len);
        address [] memory addresses = new address[](len);
        for (i=0; i < len ; i++) {
            if(packets[packetId].bufferAddresses[i] != 0x0) {
                addresses[i] = (packets[packetId].bufferAddresses[i]);
                balances[i] = (packets[packetId].receivers[packets[packetId].bufferAddresses[i]]);
            }
        }
        multisendPacketToken(packets[packetId].token, addresses, balances);
        for (i=0; i < len; i++) {
            if(packets[packetId].bufferAddresses[i] != 0x0) {
                delete packets[packetId].bufferAddresses[i];
            }
        }
    }
    function getPacketAddresses(uint32 packetId) public view returns (address[] memory){ 
        Packet storage packet = packets[packetId];
        require(packet.packetAmount>0);
        return packet.addresses;    
    }

    function getClaimAmount(uint32 packetId, address[] _addrs) public view returns (uint256[] memory) {
        Packet storage packet = packets[packetId];
        require(packet.packetAmount>0);
        uint256 len = _addrs.length;
        uint256 i = 0;
        uint256 [] memory balances = new uint256[](len);
        for(i=0; i<len; i++){
            balances[i] = packet.receivers[_addrs[i]];
        }
        return balances;
    }

    function getMyAmount(uint32 packetId, address user) public view returns(uint256){
        Packet storage packet = packets[packetId];
        require(packet.receivers[user]>0, 'you did not claim');
        return packet.receivers[user];
    }

    function getSeedPacketId(uint256 seed) public view returns(uint32){
        return uint32(uintStorage[keccak256("pp", seed)]);
    }
     function getSecretPacketId(string secret) public view returns(uint32){
        return uint32(uintStorage[keccak256("pp", secret)]);
    }
    function claimSeedPacket(uint32 packetId, uint256 seed, bool needDist) public payable{
        require(uint32(uintStorage[keccak256("pp", seed)]) == packetId, 'invalid pair for seed and packetId');
        claimPacket(packetId, needDist);
    }
    function claimSecretPacket(string secret, bool needDist) public payable{
        uint32 packetId = uint32(uintStorage[keccak256("pp", secret)]);

        claimPacket(packetId, needDist);
    }
    function packetsendToken(address token, uint256 amount) private {
        if (token == 0x000000000000000000000000000000000000bEEF){
            packetsendEther();
        } else {
            ERC20 erc20token = ERC20(token);
            erc20token.transferFrom(msg.sender, address(this), amount);
            setTxCount(msg.sender, txCount(msg.sender).add(1));
            emit Packetstarted(amount, token);
        }
    }
    function multisendPacketToken(address token, address[] _contributors, uint256[] _balances) private {
        if (token == 0x000000000000000000000000000000000000bEEF){
            multisendPacketEther(_contributors, _balances);
        } else {
            uint256 total = 0;
            ERC20 erc20token = ERC20(token);
            uint8 i = 0;
            for (i; i < _contributors.length; i++) {
                if(_contributors[i] == address(0x0)){
                    continue;
                }
                erc20token.transferFrom(address(this), _contributors[i], _balances[i]);
                total += _balances[i];
            }
            emit Packetended(total, token);
        }
    }
    function packetsendEther() private {
        uint256 total = msg.value;
        uint256 pfee = currentFee(msg.sender);
        require(total >= pfee);
        total = total.sub(pfee);
        address(this).transfer(total);
        setTxCount(msg.sender, txCount(msg.sender).add(1));
        emit Packetstarted(msg.value, 0x000000000000000000000000000000000000bEEF);
    }
    function multisendPacketEther(address[] _contributors, uint256[] _balances) private {
        uint256 i = 0;
        uint256 total  = 0;
        for (i; i < _contributors.length; i++) {
            if(_contributors[i] == address(0x0)){
                continue;
            }
            _contributors[i].transfer(_balances[i]);
            total.add(_balances[i]);
        }
        emit Packetstarted(total, 0x000000000000000000000000000000000000bEEF);
    }
    
    function claimMyPacket(uint32 packetId) public{
        Packet storage packet = packets[packetId];
        require(msg.sender == packet.owner);
        require(packet.remainCount > 0 && packet.remainAmount > 0);
        distributePacket(packetId);
        if(packet.token == 0x000000000000000000000000000000000000bEEF){
            msg.sender.transfer(packet.remainAmount);
            packets[packetId].remainCount = 0;
            packets[packetId].remainAmount = 0;
            emit ClaimedTokens(packet.token, msg.sender, packet.remainAmount);
            return;
        }
        ERC20 erc20token = ERC20(packet.token);
        erc20token.transfer(msg.sender, packet.remainAmount);
        packets[packetId].remainCount = 0;
        packets[packetId].remainAmount = 0;
        emit ClaimedTokens(packet.token, msg.sender, packet.remainAmount);
    }

    function claimTokens(address _token) public onlyOwner {
        if (_token == 0x0) {
            owner().transfer(address(this).balance);
            emit ClaimedTokens(_token, owner(), balance);
            return;
        }
        ERC20 erc20token = ERC20(_token);
        uint256 balance = erc20token.balanceOf(this);
        erc20token.transfer(owner(), balance);
        emit ClaimedTokens(_token, owner(), balance);
    }
    
    function setTxCount(address customer, uint256 _txCount) private {
        uintStorage[keccak256("txCount", customer)] = _txCount;
    }

}