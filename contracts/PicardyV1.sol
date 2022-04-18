// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./NftBase.sol";
import "./Marketplace.sol";

contract PicardyV1 is Ownable, Marketplace, IERC721Receiver {
    using SafeMath for uint;

    uint royaltyUpdate = 4 weeks;
    
    struct Artist{
        address artistAddress;
        string artistName;
    }

    struct Royalty{
        address artist;
        NftBase royaltyNft;
        uint totalSupply;
        uint saleCount;
        uint percentage;
        uint price;
        bool saleComplete;
        string artistName;
        string name;
        uint RewardlastUpdated;
    }

    struct Ticket{
        address artist;
        NftBase ticketNft;
        uint totalSupply;
        uint saleCount;
        uint price;
        bool saleComplete;
        string artistName;
        string name;
    }

    mapping (string => mapping(string => NftBase)) ticketSale;
    mapping (string => mapping(string => NftBase)) royaltySale;
    mapping (string => Royalty[]) artistToRoyaltyLog;
    mapping (string => Ticket[]) artistToTicketLog;
    mapping (address => Artist[]) artistMap;
    mapping (string => mapping(string => Royalty)) artistToRoyalty;
    mapping (string => mapping(string => Ticket)) artistToTicket;
    mapping (string => bool) artistExist;
    mapping (string => mapping(string => uint)) artistRoyaltyBalance;
    mapping (string => mapping(string => uint[])) royaltyTokenId;
    mapping (string => mapping(string => mapping(uint => uint))) tokenRewardBalance;
    mapping (string => mapping(string => mapping(uint => uint))) tokenRewardClaimTime;
    mapping (string => mapping(string => bool)) isUpdated;

    Royalty[] royaltySaleLog;
    Ticket[] ticketSaleLog;

    modifier onlyArtist(string memory _artistName){
        require(artistExist[_artistName] == true, "This artist doesnt exist");
        _;
    }

    function join(string memory _artistName) external {
        Artist[] storage newArtist = artistMap[msg.sender];
        require(artistExist[_artistName] == false);
        newArtist.push(Artist(msg.sender, _artistName));
        artistExist[_artistName] = true;
    }

    function createRoyaltySale(
        uint _maxSupply, 
        uint _maxMintAmount, 
        uint _cost, 
        uint _percentage, 
        string memory _name, 
        string memory _symbol, 
        string memory _initBaseURI, 
        string memory _artistName
    ) external onlyArtist(_artistName){
        require(_cost > 0);
        NftBase newRoyaltySale = new NftBase(
            _maxSupply,
            _maxMintAmount,
            _cost,
            _name,
            _symbol,
            _initBaseURI,
            _artistName,
            address(this),
            msg.sender
        );

        royaltySale[_artistName][_name] = newRoyaltySale;
        
        Royalty memory royalty = (
            Royalty(
                msg.sender, 
                newRoyaltySale, 
                _maxSupply, 
                0, 
                _percentage, 
                _cost, 
                false, 
                _artistName, 
                _name,
                0
            )
        );

        artistToRoyalty[_artistName][_name] = royalty;
        artistToRoyaltyLog[_artistName].push(royalty);
        royaltySaleLog.push(royalty);
    }

    function buyRoyalty(string memory _artistName, string memory _name, uint _amount) external payable{
        require(artistExist[_artistName] == true, "Artist Does Not Exist");
        require(artistToRoyalty[_artistName][_name].saleComplete == false, "Royalty Sale Completed");
        require(msg.value >= artistToRoyalty[_artistName][_name].price.mul(_amount), "Not Enough Token To Make Purchase");
       
        royaltySale[_artistName][_name].mint(_amount);
        uint[] memory tokenId = getRoyaltyNft(_artistName, _name);
        
        
        uint saleCount = artistToRoyalty[_artistName][_name].saleCount;
        saleCount = saleCount.add(_amount);

        for(uint tokenIdIndex = 0; tokenIdIndex < tokenId.length; tokenIdIndex++){
            royaltyTokenId[_artistName][_name].push(tokenId[tokenIdIndex]);
            transferRoyalty(_artistName, _name, tokenId[tokenIdIndex]);
        } 

        if(saleCount == artistToRoyalty[_artistName][_name].totalSupply){
            artistToRoyalty[_artistName][_name].saleComplete = true;
        }
    }

    function updateRoyaltyBalance(string memory _artistName, string memory _name, uint _amount) external onlyOwner{
        require(artistExist[_artistName] == true, "Artist Does Not Exist");
        require(artistToRoyalty[_artistName][_name].RewardlastUpdated > artistToRoyalty[_artistName][_name].RewardlastUpdated.add(royaltyUpdate), "Not time for update");

        uint[] memory tokenIds = royaltyTokenId[_artistName][_name];

        uint royaltyBalance = _amount * artistToRoyalty[_artistName][_name].percentage / 100;
        uint percentagePerToken = artistToRoyalty[_artistName][_name].percentage.div(artistToRoyalty[_artistName][_name].totalSupply);
        uint rewardPerToken = royaltyBalance * percentagePerToken / 100;

        for(uint tokenIdIndex = 0; tokenIdIndex < tokenIds.length; tokenIdIndex++){
            uint tokenReward = tokenRewardBalance[_artistName][_name][tokenIds[tokenIdIndex]];
            tokenReward = tokenReward + rewardPerToken;
        } 

        artistRoyaltyBalance[_artistName][_name] = artistRoyaltyBalance[_artistName][_name] + _amount;
        artistToRoyalty[_artistName][_name].RewardlastUpdated = block.timestamp;
    }
.
    function claimRoyalty(string memory _artistName, string memory _name) external payable {
        require(artistExist[_artistName] == true, "Artist Does Not Exist");
        require(artistToRoyalty[_artistName][_name].saleComplete == true, "Royalty Sale Not Complete");
        
        uint[] memory tokenId = getOwnerRoyaltyNft(_artistName, _name);

        for(uint tokenIdIndex = 0; tokenIdIndex < tokenId.length; tokenIdIndex++){
            require(tokenRewardBalance[_artistName][_name][tokenId[tokenIdIndex]] > 0, "No royalty to claim");
            
            uint newTokenBalance =  tokenRewardBalance[_artistName][_name][tokenId[tokenIdIndex]];
            artistRoyaltyBalance[_artistName][_name] = artistRoyaltyBalance[_artistName][_name].sub(newTokenBalance);
            (bool os, ) = payable(msg.sender).call{value: newTokenBalance }("");
            require(os); 
            
            newTokenBalance = 0;
            tokenRewardClaimTime[_artistName][_name][tokenId[tokenIdIndex]] = block.timestamp;
            
        }

    }
   
   function createTicket(
        uint _maxSupply, 
        uint _maxMintAmount,
        uint _cost,
        string memory _name, 
        string memory _symbol, 
        string memory _initBaseURI, 
        string memory _artistName
    ) external onlyArtist(_artistName){
        NftBase newNftTicket = new NftBase(
            _maxSupply,
            _maxMintAmount,
            _cost,
            _name,
            _symbol,
            _initBaseURI,
            _artistName,
            address(this),
            msg.sender
        );
        
        ticketSale[_artistName][_name] = newNftTicket;

        Ticket memory ticket = Ticket(
            msg.sender,
            newNftTicket,
            _maxSupply,
            0,
            _cost,
            false,
            _artistName,
            _name
        );

        artistToTicket[_artistName][_name] = ticket;
        artistToTicketLog[_artistName].push(ticket);
        ticketSaleLog.push(ticket);
    }

    function buyTicket(string memory _artistName, string memory _name, uint _amount) external payable{
        require(artistExist[_artistName] == true, "Artist Does Not Exist");
        require(artistToTicket[_artistName][_name].saleComplete == false, "Ticket Sale Completed");
        require(msg.value >= artistToTicket[_artistName][_name].price.mul(_amount), "Not Enough Token To Make Purchase");
       
        ticketSale[_artistName][_name].mint(_amount);
        uint[] memory tokenId = getTicketNft(_artistName, _name);
        
        
        uint saleCount = artistToTicket[_artistName][_name].saleCount;
        saleCount = saleCount.add(_amount);

        for(uint tokenIdIndex = 0; tokenIdIndex < tokenId.length; tokenIdIndex++){
            royaltyTokenId[_artistName][_name].push(tokenId[tokenIdIndex]);
            transferTicket(_artistName, _name, tokenId[tokenIdIndex]);
        } 

        if(saleCount == artistToTicket[_artistName][_name].totalSupply){
            artistToTicket[_artistName][_name].saleComplete = true;
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override returns (bytes4) { 

        return this.onERC721Received.selector;
    }


    function getTicketNft(string memory _artistName, string memory _name) internal view returns (uint256[] memory tokenId) {
       NftBase(ticketSale[_artistName][_name]).walletOfOwner(address(this));
       return tokenId;
   }

    function getOwnerTicketNft(string memory _artistName, string memory _name) public view returns(uint256[] memory tokenId) {
       NftBase(ticketSale[_artistName][_name]).walletOfOwner(msg.sender);
       return tokenId;
   }

    function getRoyaltyAdress(string memory _artistName, string memory _name) external view returns(NftBase){
        return royaltySale[_artistName][_name];
    }

    function getTicketAdress(string memory _artistName, string memory _name) external view returns(NftBase){
        return ticketSale[_artistName][_name];
    }

     function getRoyaltyNft(string memory _artistName, string memory _name) internal view returns (uint256[] memory tokenId) {
       NftBase(royaltySale[_artistName][_name]).walletOfOwner(address(this));
       return tokenId;
   }

    function getOwnerRoyaltyNft(string memory _artistName, string memory _name) public view returns(uint256[] memory tokenId) {
       NftBase(royaltySale[_artistName][_name]).walletOfOwner(msg.sender);
       return tokenId;
   }

    function transferRoyalty(string memory _artistName, string memory _name, uint256 tokenId) internal {
        IERC721Enumerable(royaltySale[_artistName][_name]).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function transferTicket(string memory _artistName, string memory _name, uint256 tokenId) internal {
        IERC721Enumerable(ticketSale[_artistName][_name]).safeTransferFrom(address(this), msg.sender, tokenId);
    }

}