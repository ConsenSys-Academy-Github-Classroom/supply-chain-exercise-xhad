// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.9.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol"; 

contract SupplyChain {

  using SafeMath for uint;

  address public owner;
  uint    public skuCount;

  mapping(uint => Item) public items;

  enum State {
    ForSale,
    Sold,
    Shipped,
    Received
  }

  struct Item {
    string  name;
    uint    sku;
    uint    price;
    State   state;
    address payable seller;
    address payable buyer;
  }

  /* 
   * Events
   */

  event LogForSale(uint sku);
  event LogSold(uint sku);
  event LogShipped(uint sku);
  event LogReceived(uint sku);

  /* 
   * Modifiers
   */

  modifier paidEnough(uint _price) { 
    // require(msg.value >= _price); 
    _;
  }

  modifier checkValue(uint sku, uint value) {
    uint change = value > items[sku].price ? value.sub(items[sku].price) : 0;
    if (change > 0) {
      bool refund = items[sku].buyer.send(change);
      require(refund, "SC:REFUND_FAILED");
    }    
    _;
  }

  modifier isForSale (uint sku) {
    require(items[sku].state == State.ForSale, "SC:NOT_FOR_SALE");
    _;
  }

  modifier isSufValue (uint amount, uint sku) {
    require(amount >= items[sku].price, "SC:INSUF_VALUE");
    _;
  }

  modifier isSold(uint sku) {
    require(items[sku].state == State.Sold, "SC:UNSOLD");
    _;
  }

  modifier isSeller(uint sku, address seller) {
    require(items[sku].seller == seller, "SC:NOT_SELLER");
    _;
  }

  modifier isBuyer(uint sku, address buyer) {
    require(items[sku].buyer == buyer, "SC:NOT_BUYER");
    _;
  }

  modifier isShipped(uint sku) {
    require(items[sku].state == State.Shipped, "SC:UNSHIPPED");
    _;
  }

  constructor() public {
    // 1. Set the owner to the transaction sender
    owner = msg.sender;
    // 2. Initialize the sku count to 0. Question, is this necessary?
    skuCount = 0;
  }

  function addItem(string memory _name, uint _price) public returns (bool) {

    items[skuCount] = Item({
      name:   _name,
      sku:    skuCount,
      price:  _price,
      state:  State.ForSale,
      seller: msg.sender,
      buyer:  address(0)
    });

    skuCount = skuCount.add(1);
    emit LogForSale(skuCount);
    return true;
  }

  function fetchItem(uint sku) public view returns (Item memory) {
    return items[sku];
  }

  function buyItem(uint sku) public payable isForSale(sku) isSufValue(msg.value, sku) checkValue(sku, msg.value) returns (bool) {

      items[sku].state = State.Sold;
      items[sku].buyer = msg.sender;
      
      bool success = items[sku].seller.send(items[sku].price);
      require(success, "SC:SEND_FAILED");

      emit LogSold(sku);
      return true;
  }

  function shipItem(uint sku) public isSold(sku) isSeller(sku, msg.sender) {
    items[sku].state = State.Shipped;
    emit LogShipped(sku);
  }

  function receiveItem(uint sku) public isShipped(sku) isBuyer(sku, msg.sender) {
    items[sku].state = State.Received;
    emit LogReceived(sku);
  }
}
