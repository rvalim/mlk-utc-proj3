pragma solidity >=0.4.24;


import "../../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

// Import the library 'Roles'
import "../access-control/FarmerRole.sol";
import "../access-control/DistributorRole.sol";
import "../access-control/RetailerRole.sol";
import "../access-control/ConsumerRole.sol";


// Define a contract 'Supplychain'
contract SupplyChain is Ownable, FarmerRole, DistributorRole, RetailerRole, ConsumerRole {

  struct Farm {
    address      originFarmerID; // Farmer Address
    string       originFarmName; // Farmer Name
    string       originFarmInformation;  // Farmer Information
    string       originFarmLatitude; // Farm Latitude
    string       originFarmLongitude;  // Farm Longitude
    uint[]       harvests;
  }

  enum HarvestState { Planted, Harvested, Processed, Packed }
  struct ItemHarvest {
    uint         harvestId;
    uint         upc; // Universal Product Code (UPC), generated by the Farmer, goes on the package, can be verified by the Consumer
    Farm         farm;
    string       productNotes; // Product Notes
    HarvestState state;
  }

  enum SellState { ForSale, Sold, Shipped, Received }
  struct ItemBag {
    uint            sku; // Stock Keeping Unit (SKU)
    uint            productID;  // Product ID potentially a combination of upc + sku
    uint            productPrice; // Product Price
    ItemHarvest     harvest;
    SellState       state;  // Product State as represented in the enum above
    address payable ownerID;  // Metamask-Ethereum address of the current owner as the product moves through 8 stages
    address         buyerId;
    address         distributorID;  // Metamask-Ethereum address of the Distributor
    address         retailerID; // Metamask-Ethereum address of the Retailer
    address         consumerID; // Metamask-Ethereum address of the Consumer
  }

 // Define a variable called 'sku' for Stock Keeping Unit (SKU)
  uint sku;
  uint itemHSeed;
  uint itemBSeed;
  mapping (address => Farm)   farms;
  mapping (uint => ItemHarvest) itemHarvests;
  mapping (uint => ItemBag)     itemBags;


  event Planted(uint id);
  event Harvested(uint id);
  event Processed(uint id);
  event Packed(uint id);
  event ForSale(uint id);
  event Sold(uint id);
  event Shipped(uint id);
  event Received(uint id);

  constructor() public {
      itemBSeed = 0;
      itemHSeed = 0;
      sku = 0;

      Farm memory farm;
      farm.originFarmerID = msg.sender;
      farm.originFarmName = 'Ricardo Valim';
      farm.originFarmInformation = 'The base Farm';
      farm.originFarmLatitude = '-23.628324';
      farm.originFarmLongitude = '-46.575751';
      farms[msg.sender] = farm;
  }

  function registerFarm(
    address _originFarmerID,
    string memory _originFarmName,
    string memory _originFarmInformation,
    string memory _originFarmLatitude,
    string memory _originFarmLongitude)
    public
    onlyFarmer(){
    Farm memory farm;

    farm.originFarmerID = _originFarmerID;
    farm.originFarmName = _originFarmName;
    farm.originFarmInformation = _originFarmInformation;
    farm.originFarmLatitude = _originFarmLatitude;
    farm.originFarmLongitude = _originFarmLongitude;

    farms[_originFarmerID] = farm;

    super.addFarmer(_originFarmerID);
  }

  function toPlantItem(uint _upc,
    string memory _productNotes)
    public
    onlyFarmer()
    verifyCaller(farms[msg.sender].originFarmerID) // To validate user registered as farmer
  {
    itemHSeed = itemHSeed + 1;
    ItemHarvest memory item;

    item.upc = _upc; // Universal Product Code (UPC); generated by the Farmer; goes on the package; can be verified by the Consumer
    item.farm = farms[msg.sender]; // Metamask-Ethereum address of the Farmer
    item.productNotes = _productNotes; // Product Notes
    item.state = HarvestState.Planted;  // Product State as represented in the enum above

    itemHarvests[itemHSeed] = item;

    farms[msg.sender].harvests.push(itemHSeed);

    emit Planted(itemHSeed);
  }

  function harvestItem(uint harvestId)
    public
    planted(harvestId)
    onlyFarmer()
    verifyCaller(itemHarvests[harvestId].farm.originFarmerID)
  {
    itemHarvests[harvestId].state = HarvestState.Harvested;

    emit Harvested(harvestId);
  }

  function processItem(uint harvestId) public
    harvested(harvestId)
    verifyCaller(itemHarvests[harvestId].farm.originFarmerID)
  {
    itemHarvests[harvestId].state = HarvestState.Processed;

    emit Processed(harvestId);
  }

  function packItem(uint harvestId) public
    processed(harvestId)
    verifyCaller(itemHarvests[harvestId].farm.originFarmerID)
  {
    itemHarvests[harvestId].state = HarvestState.Packed;

    emit Packed(harvestId);
  }

  function putForSaleByFarmer(uint harvestId, uint price) public
    onlyFarmer()
    packed(harvestId)
    verifyCaller(itemHarvests[harvestId].farm.originFarmerID)
  {
    sku = sku + 1;

    ItemBag memory item;

    item.sku = sku;
    item.ownerID = msg.sender;
    item.harvest = itemHarvests[harvestId];
    item.productID = sku * 1000000 + item.harvest.upc;
    item.productPrice = price;
    item.state = SellState.ForSale;

    itemBags[sku] = item;

    emit ForSale(item.sku);
  }

  function putForSaleByDistributor(uint _sku, uint price) public
    onlyDistributor()
    received(_sku)
    verifyCaller(itemBags[_sku].ownerID)
  {
    _putForSale(_sku, price);
  }

  function putForSaleByRetailer(uint _sku, uint price) public
    onlyRetailer()
    received(_sku)
    verifyCaller(itemBags[_sku].ownerID)
  {
    _putForSale(_sku, price);
  }

  function _putForSale(uint _sku, uint _price) internal
  {
    itemBags[_sku].productPrice = _price;
    itemBags[_sku].state = SellState.ForSale;

    emit ForSale(_sku);
  }

  function buyFromFarmer(uint _sku) public payable
    onlyDistributor()
    isFarmer(itemBags[_sku].ownerID)
  {
    _buyItem(_sku);
  }

  function buyFromDistributor(uint _sku) public payable
    onlyRetailer()
    isDistributor(itemBags[_sku].ownerID)
  {
    _buyItem(_sku);
  }

  function buyFromRetailer(uint _sku) public payable
    onlyConsumer()
    isRetailer(itemBags[_sku].ownerID)
  {
    _buyItem(_sku);
  }

  function _buyItem(uint _sku) internal
    forSale(_sku)
    paidEnough(itemBags[_sku].productPrice)
    checkValue(_sku)
  {
    itemBags[_sku].state = SellState.Sold;
    itemBags[_sku].buyerId = msg.sender;
    itemBags[_sku].ownerID.transfer(msg.value);

    emit Sold(_sku);
  }

  function shipItem(uint _sku) public
    sold(_sku)
    verifyCaller(itemBags[_sku].ownerID)
  {
    itemBags[_sku].state = SellState.Shipped;

    emit Shipped(_sku);
  }

  function receiveItem(uint _sku) public
    shipped(_sku)
    verifyCaller(itemBags[_sku].buyerId)
  {
    itemBags[_sku].state = SellState.Received;
    itemBags[_sku].ownerID = msg.sender;

    emit Received(_sku);
  }

  // Define a modifer that verifies the Caller
  modifier verifyCaller(address _address) {
    require(msg.sender == _address, "Are you joking?");
    _;
  }

  // Define a modifier that checks if the paid amount is sufficient to cover the price
  modifier paidEnough(uint _price) {
    require(msg.value >= _price, "I can not accept less than it worth");
    _;
  }

  // Define a modifier that checks the price and refunds the remaining balance
  modifier checkValue(uint _sku) {
    _;
    uint _price = itemBags[_sku].productPrice;
    uint amountToReturn = msg.value - _price;
    msg.sender.transfer(amountToReturn);
  }

  // Define a modifier that checks if an item.state of a upc is Harvested
  modifier planted(uint _sku) {
    require(itemHarvests[_sku].state == HarvestState.Planted, "Not in harvest");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Harvested
  modifier harvested(uint _sku) {
    require(itemHarvests[_sku].state == HarvestState.Harvested, "Not in harvest");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Processed
  modifier processed(uint _sku) {
    require(itemHarvests[_sku].state == HarvestState.Processed, "Not in process");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Packed
  modifier packed(uint _sku) {
    require(itemHarvests[_sku].state == HarvestState.Packed, "Not in package");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is ForSale
  modifier forSale(uint _sku) {
    require(itemBags[_sku].state == SellState.ForSale, "Not for sale");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Sold
  modifier sold(uint _sku) {
    require(itemBags[_sku].state == SellState.Sold, "Not sold yet");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Shipped
  modifier shipped(uint _sku) {
    require(itemBags[_sku].state == SellState.Shipped, "Not shipped yet");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Received
  modifier received(uint _sku) {
    require(itemBags[_sku].state == SellState.Received, "Still not received");
    _;
  }

  function fetchFarm(address farmAddress) public view returns(
    string memory originFarmName,
    string memory originFarmInformation,
    string memory originFarmLatitude,
    string memory originFarmLongitude,
    uint[] memory harvests
  ) {
    originFarmName = farms[farmAddress].originFarmName;
    originFarmInformation = farms[farmAddress].originFarmInformation;
    originFarmLatitude = farms[farmAddress].originFarmLatitude;
    originFarmLongitude = farms[farmAddress].originFarmLongitude;
    harvests = farms[farmAddress].harvests;
  }

  function fetchHarvest(uint harvestId) public view returns(
    uint          upc,
    address       farm,
    string memory productNotes,
    string memory state
  ){
    upc = itemHarvests[harvestId].upc;
    farm = itemHarvests[harvestId].farm.originFarmerID;
    productNotes = itemHarvests[harvestId].productNotes;

    uint _state = uint(itemHarvests[harvestId].state);

    if(_state == 0) {
      state = "Planted";
    }
    else if(_state == 1) {
      state = "Harvested";
    }
    else if(_state == 2) {
      state = "Processed";
    }
    else if(_state == 3) {
      state = "Packed";
    }
  }

  // Define a function 'fetchItemBufferOne' that fetches the data
  function fetchBags(uint _sku) public view returns
    (
      uint          itemSKU,
      uint          itemUPC,
      address       ownerID,
      address       buyerId,
      address       originFarmerID,
      string memory state
    )
  {
    itemSKU = itemBags[_sku].sku;
    ownerID = itemBags[_sku].ownerID;
    buyerId = itemBags[_sku].buyerId;
    itemUPC = itemBags[_sku].harvest.upc;
    originFarmerID = itemBags[_sku].harvest.farm.originFarmerID;

    uint _state = uint(itemBags[_sku].state);

    if(_state == 0) {
      state = "ForSale";
    }
    else if(_state == 1) {
      state = "Sold";
    }
    else if(_state == 2) {
      state = "Shipped";
    }
    else if(_state == 3) {
      state = "Received";
    }
  }
}
