// SPDX-License-Identifier: MIT

/**

+------+.     
|`.    | `.    
|  `+--+---+   
|   |  |   |  
+---+--+.  |   
 `. |    `.|   
   `+------+   

**/

pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import 'base64-sol/base64.sol';

/// @title BasedCubes
/// @notice 100% fully on-chain contract
contract BasedCubes is ERC721A, Ownable {

    string[] public bgPaletteColors = [
        '0052FF', 
        '735DFF', 
        'FCD22D', 
        'FFFFFF', 
        '54DCE7', 
        'FFA500', 
        'FF7DCB'
    ];

    enum MintStatus {
        CLOSED, // 0
        PUBLIC // 1
    }

    uint256 public mintPrice = 0.001 ether;
    MintStatus public mintStatus = MintStatus.CLOSED;
    uint256 public maxTokensOwnableInWallet = 25;
    mapping(uint256 => address) public minter; 

    constructor() ERC721A("Based Onchain Cubes", "BASEDCUBES") {
    }

    modifier verifyTokenId(uint256 tokenId) {
        require(tokenId >= _startTokenId() && tokenId <= _totalMinted(), "Invalid tokenId");
        _;
    }

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(
            _ownershipOf(tokenId).addr == _msgSender() ||
                getApproved(tokenId) == _msgSender(),
            "Not approved nor owner"
        );
        
        _;
    }

    function _startTokenId() override internal pure virtual returns (uint256) {
        return 1;
    }

    function _mintCube(address to, uint256 numToMint)  private {
        uint256 startTokenId = _startTokenId() + _totalMinted();
        for(uint256 tokenId = startTokenId; tokenId < startTokenId+numToMint; tokenId++) {
            minter[tokenId] = to;
        }

         _safeMint(to, numToMint);
    }

    function reserveCube(address to, uint256 numToMint) external onlyOwner {
        _mintCube(to, numToMint);
    }

    function reserveCubeMany(address[] calldata recipients, uint256 numToMint) external onlyOwner {
        uint256 num = recipients.length;
        require(num > 0);

        for (uint256 i = 0; i < num; ++i) {
            _mintCube(recipients[i], numToMint);    
        }
    }

    /// @notice Mint
    /// @param numToMint The number to mint 
    function publicMintCube(uint256 numToMint) external payable {
        require(mintStatus == MintStatus.PUBLIC, "Public mint closed");
        require(msg.value >= _getPrice(numToMint), "Incorrect payable" );

        // check max mint
        require(_numberMinted(msg.sender) + numToMint <= maxTokensOwnableInWallet, "Exceeds max mints");

        _mintCube(msg.sender, numToMint);
    }

    // taken from 'ERC721AQueryable.sol'
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (uint256 i = _startTokenId(); tokenIdsIdx != tokenIdsLength; ++i) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    function getNumMinted() external view returns (uint256) {
        return _totalMinted();
    }

    function _getPrice(uint256 numPayable) private view returns (uint256) {
        return numPayable * mintPrice;
    }

    function setPricing(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function setTokenMaxPerWallet(uint256 maxTokens) external onlyOwner {
        maxTokensOwnableInWallet = maxTokens;
    }

    function getPrice(uint256 numToMint) external view returns (uint256) {
        return _getPrice(numToMint);
    }

    function setMintStatus(uint256 _status) external onlyOwner {
        mintStatus = MintStatus(_status);
    }

    function numberMinted(address addr) external view returns(uint256){
        return _numberMinted(addr);
    }

    function getSVG(uint256 tokenId, address wallet) external view returns (string memory) {
        return _getSVG(tokenId, uint256(uint160(wallet)));
    }

    function _randStat(uint256 seed, int div, int min, int max) private pure returns (int) {
        return min + (int(seed)/div) % (max-min);
    }

    function _getCubes(uint256, uint256 wallet) internal pure returns (string memory) {
        // cubes
        string memory cubes;

        int stacksWidth = 4;
        //int stacksHeight = 4;
        int stacksHeight = _randStat(wallet, 8, 1, 5);

        int deltaX = 21;
        int deltaY = 12;
        int yGridDelta = 36;

        int xStart = 150 -deltaX;
        int yStart = 150 - stacksHeight * yGridDelta / 2 - yGridDelta + deltaY;

        for (int y = stacksHeight-1; y >= 0; y = y-1) {
            for (int z = 0; z < stacksWidth; z = z+1) {
                for (int x = 0; x < stacksWidth; x = x+1) {
                    uint256 hash = uint256(keccak256(abi.encodePacked(wallet, uint256(x), uint256(y), uint256(z))));
        
                    if (hash % 2 == 0)
                    {
                        continue;
                    }

                    int posX = xStart + deltaX * x - deltaX * z;
                    int posY = yStart + y*yGridDelta + deltaY * x + deltaY * z;

                    cubes = string(abi.encodePacked(cubes, ' <use xlink:href="#cube" x="',Strings.toString(posX),'" y="',Strings.toString(posY), '"></use>'));
                }
            }
        }

        return cubes;
    }

    function _getSVG(uint256 tokenId, uint256 wallet) internal view returns (string memory) {

        string memory image = string(abi.encodePacked(
          '<svg class="cubecolor" viewBox="0 0 300 300"  xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
          
          // background color
          '<rect width="100%" height="100%" fill="#', bgPaletteColors[wallet % bgPaletteColors.length], '"/>',

          // styles and whatnot
          '<style> <![CDATA[.cube-unit {fill-opacity: .9; stroke-miterlimit:0; } .cubecolor {--mainColor: #555555; --strokeColor: #000000; --lightColor: #ffffff; --darkColor: #000000; } @keyframes moveX {to { transform: translateX(var(--translate, 35px)); } } @keyframes moveY {to { transform: translateY(var(--translate, -35px)); } } .m-left, .m-right {animation: 2s moveX alternate infinite paused; } .m-up, .m-down {animation: 2s moveY alternate infinite paused; } .m-left { --translate: -50px; } .m-right { --translate: 50px; } svg:hover * { animation-play-state: running; } ]]> </style> <defs> <g id="cube" class="cube-unit"> <rect width="21" height="24" fill="var(--lightColor)" stroke="var(--strokeColor)" transform="skewY(30)"/> <rect width="21" height="24" fill="var(--darkColor)" stroke="var(--strokeColor)" transform="skewY(-30) translate(21 24.3)"/> <rect width="21" height="21" fill="var(--mainColor)" stroke="var(--strokeColor)" transform="scale(1.41,.81) rotate(45) translate(0 -21)"/> </g> </defs>',

          // cubes
          _getCubes(tokenId, wallet),

          // text of owner
          '<text x="2%" y="97%" text-anchor="left" font-family="monospace" font-size="5">', unicode"🔵" ,' based on-chain enjoyoooor: ', Strings.toHexString(uint256(uint160(wallet))), '</text></svg>'
        ));

        return image;
      }

    function _tokenURI(uint256 tokenId) private view returns (string memory) {
        uint256 wallet = uint256(uint160(ownerOf(tokenId)));
        string memory image = _getSVG(tokenId, wallet);

        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name": "',  unicode"🔵", ' Based Onchain Cubes #', Strings.toString(tokenId),'",',
                    '"description": "100% on-chain generative art cubes seeded with the owner\'s wallet address, celebrating the mainnet GA launch of Base in August 9th, 2023.",',
                    '"attributes":[',
                        '{"trait_type":"Background", "value":"#',bgPaletteColors[wallet % bgPaletteColors.length],'"},',
                        '{"trait_type":"Minter", "value":"',Strings.toHexString(uint256(uint160(minter[tokenId]))),'"},',
                        '{"trait_type":"Owner", "value":"',Strings.toHexString(wallet),'"}'
                    '],',
                    '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(image)), '"}' 
                )
            ))
        );

        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function tokenURI(uint256 tokenId) override(ERC721A) public view verifyTokenId(tokenId) returns (string memory) {
        return _tokenURI(tokenId);
    }

    function withdraw(address to) public onlyOwner {
        uint256 contractBalance = address(this).balance;
        (bool success,) = payable(to).call{ value: contractBalance }("");
        require(success, "WITHDRAWAL_FAILED");
    }
}