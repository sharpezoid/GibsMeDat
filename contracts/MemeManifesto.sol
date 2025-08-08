// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/// @title MemeManifesto
/// @notice Collaborative on-chain manifesto divided into chapters. Contributors
/// holding a Red Book may add pages; once a chapter reaches the page limit,
/// contributors can mint an NFT containing that chapter's text.
contract MemeManifesto is ERC721 {
    IERC1155 public immutable redBook;
    uint256 public constant RED_BOOK_ID = 1; // token id for RedBook Maximalist
    uint256 public constant MAX_PAGE_LENGTH = 280; // maximum page text length
    uint256 public constant MAX_PAGES_PER_CHAPTER = 10; // pages per chapter

    struct Chapter {
        uint256 pageCount;
        mapping(uint256 => string) pages; // page number => text
        mapping(address => bool) contributed; // contributor list
        mapping(address => bool) claimed; // claim status
        bool finalized; // whether chapter is complete
    }

    uint256 public currentChapter = 1; // active chapter being written
    uint256 private _tokenIdTracker; // incremental token id
    mapping(uint256 => Chapter) private _chapters; // chapter id => Chapter data
    mapping(uint256 => uint256) public tokenChapter; // token id => chapter id

    event PageAdded(
        uint256 indexed chapter,
        uint256 indexed page,
        address indexed comrade,
        string text
    );
    event ChapterFinalized(uint256 indexed chapter);
    event ChapterTokenClaimed(
        uint256 indexed chapter,
        address indexed comrade,
        uint256 tokenId
    );

    constructor(address _redBook) ERC721("Meme Manifesto", "MANIFESTO") {
        redBook = IERC1155(_redBook);
    }

    modifier onlyRedBook() {
        require(redBook.balanceOf(msg.sender, RED_BOOK_ID) > 0, "no red book");
        _;
    }

    /// @notice Propose a new page to the current chapter of the Manifesto.
    function proposePage(string calldata text) external onlyRedBook {
        Chapter storage chapter = _chapters[currentChapter];
        require(!chapter.finalized, "chapter complete");
        require(bytes(text).length > 0, "empty");
        require(bytes(text).length <= MAX_PAGE_LENGTH, "page too long");

        chapter.pageCount += 1;
        chapter.pages[chapter.pageCount] = text;
        chapter.contributed[msg.sender] = true;

        emit PageAdded(currentChapter, chapter.pageCount, msg.sender, text);

        if (chapter.pageCount == MAX_PAGES_PER_CHAPTER) {
            chapter.finalized = true;
            emit ChapterFinalized(currentChapter);
            currentChapter += 1; // start a new chapter
        }
    }

    /// @notice Claim an NFT representing a completed chapter. Only addresses
    /// that contributed at least one page to the chapter may claim.
    /// @param chapterId The chapter to claim.
    function claimChapter(uint256 chapterId) external {
        Chapter storage chapter = _chapters[chapterId];
        require(chapter.finalized, "chapter not finalized");
        require(chapter.contributed[msg.sender], "no contribution");
        require(!chapter.claimed[msg.sender], "already claimed");

        chapter.claimed[msg.sender] = true;
        _tokenIdTracker += 1;
        uint256 tokenId = _tokenIdTracker;
        tokenChapter[tokenId] = chapterId;
        _safeMint(msg.sender, tokenId);
        emit ChapterTokenClaimed(chapterId, msg.sender, tokenId);
    }

    /// @dev Concatenate all pages of a chapter into a single string.
    function _chapterText(uint256 chapterId) internal view returns (string memory) {
        Chapter storage chapter = _chapters[chapterId];
        bytes memory text;
        for (uint256 i = 1; i <= chapter.pageCount; i++) {
            text = abi.encodePacked(text, chapter.pages[i]);
            if (i != chapter.pageCount) {
                text = abi.encodePacked(text, "\n");
            }
        }
        return string(text);
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(tokenId);
        uint256 chapterId = tokenChapter[tokenId];
        string memory text = _chapterText(chapterId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"Meme Manifesto Chapter ',
                        Strings.toString(chapterId),
                        '","description":"',
                        text,
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}

