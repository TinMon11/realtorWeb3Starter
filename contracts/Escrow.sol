//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _id
    ) external;
}

contract Escrow is Ownable {
    address public nftAddress;
    address payable public seller;
    address public buyer;
    address public inspector;

    //@dev Modifiers onlyBuyer/Seller/Inspector to limit some functions to this roles
    modifier onlyBuyer(uint256 _nftID) {
        require(msg.sender == buyerList[_nftID], "Only buyer can call this function");
        _;
    }
   
    modifier onlySeller {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier onlyInspector {
        require(msg.sender == inspector, "Only inspector can call this function");
        _;
    }
    
    //@dev Mappings declaration
    mapping (uint256 => bool) public isListed; //El NFT está listado (True) o no (false) para la venta
    mapping (uint256 => uint256) public purchasePrice; // Precio de venta para cada NFT
    mapping (uint256 => uint256) public escrowAmount;
    mapping (uint256 => address) public buyerList;
    mapping (uint256 => bool) public inspectionPassed; // (True) si el escrow verifica todas las condiciones
    mapping (uint256 => bool) public inspectionStatus; // (True) si ya pasó el proceso de verificación
    mapping (uint256 => mapping (address => bool)) public approval;
    
    constructor(address _nftAddress, address payable _seller, address _inspector, address _buyer) 
    {
        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        buyer = _buyer;
    }

    function list(uint256 _nftID, address _buyer, uint256 _purchasePrice, uint256 _escrowAmount) public 
    payable onlySeller {
        // Transfer NFT from seller to this contract
        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftID);

        isListed[_nftID] = true;
        purchasePrice[_nftID] = _purchasePrice;
        escrowAmount[_nftID] = _escrowAmount;
        buyerList[_nftID] = _buyer;
    }
    
    // Put Under Contract (only buyer - payable escrow)   
    function depositEarnest(uint256 _nftID) payable public onlyBuyer(_nftID) {
        uint256 _depositAmount = msg.value;
        require(_depositAmount >= escrowAmount[_nftID], "Insufficient Amount");
        escrowAmount[_nftID] = msg.value;
    }

    // Update Inspection Status 
    function updateInspectionStatus(uint256 _nftID, bool _status) public    onlyInspector {
        require(isListed[_nftID] == true, "Not existing NFT");
        inspectionStatus[_nftID] = _status;
        inspectionPassed[_nftID] = _status;
    }
    
    // Approve Sale
    // Buyer & Sender have to approve the Sale
    function approveSale (uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
    }

    // Finalize Sale
    // -> Require inspection status 
    // -> Require sale to be authorized
    // -> Require funds to be correct amount
    // -> Transfer NFT to buyer
    // -> Transfer Funds to Seller
    function finalizeSale(uint256 _NFTId) public onlyInspector {
            require(approval[_NFTId][seller] = true, "Seller didnt approve this sale");
            require(approval[_NFTId][buyerList[_NFTId]], "Buyer didnt approve this transaction");
            require(inspectionPassed[_NFTId] = true, "Didnt pass the inspection yet");

                    
            isListed[_NFTId] = false;

        (bool success, ) = payable(seller).call{value: address(this).balance}("");
        require(success);

        IERC721(nftAddress).transferFrom(address(this), buyerList[_NFTId], _NFTId);
    } 
        
    // Cancel Sale (handle earnest deposit)
    // -> if inspection status is not approved, then refund, otherwise send to seller
    function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyerList[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }

    //implement a special receive function in order to receive funds and increase the balance
    //VER BIEN QUE HACE O PARA QUE ESTÁ?
    receive() external payable {}

    //function getBalance to check the current balance of the smart contract
    function getBalance() public view onlyOwner returns (uint256) {
    return address(this).balance;
    }
}

