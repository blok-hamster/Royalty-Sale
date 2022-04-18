// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftBase is ERC721Enumerable, Pausable, Ownable {
  using Strings for uint256;

  string artistName;
  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0 ether;
  uint256 public maxSupply;
  uint256 public maxMintAmount;
  bool public revealed = false;
  address picardyAddress;
  address creator;


  constructor(
    uint _maxSupply,
    uint _maxMintAmount,
    uint _cost,
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _artistName,
    address _picardyAddress,
    address _creator
  ) ERC721(_name, _symbol) {
    maxSupply = _maxSupply;
    maxMintAmount = _maxMintAmount;
    picardyAddress = _picardyAddress;
    creator = _creator;
    artistName = _artistName;
    setCost(_cost);
    setBaseURI(_initBaseURI);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function mint(uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner
  function reveal() public onlyOwner {
      revealed = true;
  }
  
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    maxMintAmount = _newmaxMintAmount;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function pause() public onlyOwner {
        _pause();
    }

  function unpause() public onlyOwner {
        _unpause();
    }
 
  function withdraw() public payable onlyOwner {

    (bool pc, ) = payable(picardyAddress).call{value: address(this).balance * 5 / 100}("");
    require(pc);

    (bool os, ) = payable(creator).call{value: address(this).balance}("");
    require(os);
  }
}