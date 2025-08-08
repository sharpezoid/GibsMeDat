// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title MemeManifesto
/// @notice Collaborative on-chain manifesto only editable by RedBook Maximalists.
contract MemeManifesto is ERC721, Ownable {
    IERC1155 public immutable redBook;
    uint256 public constant RED_BOOK_ID = 1; // token id for RedBook Maximalist
    uint256 public constant MAX_PAGE_LENGTH = 280; // maximum page text length

    uint256 public pageCount;
    mapping(uint256 => string) public pages; // page number => text
    bool public ghostMinted;

    event PageAdded(uint256 indexed page, address indexed comrade, string text);
    event GhostOfMarxMinted(address indexed comrade);

    constructor(address _redBook) ERC721("Meme Manifesto", "MANIFESTO") {
        redBook = IERC1155(_redBook);
        _safeMint(msg.sender, 1); // single manifesto NFT
    }

    modifier onlyRedBook() {
        require(redBook.balanceOf(msg.sender, RED_BOOK_ID) > 0, "no red book");
        _;
    }

    /// @notice Propose a new page to the Manifesto.
    function proposePage(string calldata text) external onlyRedBook {
        require(bytes(text).length > 0, "empty");
        require(bytes(text).length <= MAX_PAGE_LENGTH, "page too long");
        require(pageCount < 10, "manifesto complete");
        pageCount += 1;
        pages[pageCount] = text;
        emit PageAdded(pageCount, msg.sender, text);
    }

    /// @notice Once 10 pages exist, summon the Ghost of Marx NFT.
    function mintGhostOfMarx(address to) external onlyRedBook {
        require(pageCount >= 10, "not enough pages");
        require(!ghostMinted, "ghost summoned");
        ghostMinted = true;
        _safeMint(to, 2);
        emit GhostOfMarxMinted(to);
    }
}
