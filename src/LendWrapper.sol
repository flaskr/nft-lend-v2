// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "solmate/tokens/ERC721.sol";
import "./interfaces/ILendWrapper.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC165.sol";

contract LendWrapper is ERC721, ILendWrapper, IERC721Receiver {

    IERC721 private wrappedToken;

    /// @notice Stores the address of the original depositor of each managed NFT.
    mapping(uint256 => address) public originalOwner;

    /// @notice Stores lending durations for each managed tokenId
    /// @dev The mappings can be invalidated if borrowers call `terminateLending`
    mapping(uint256 => LendingDuration) public lendingDurations;

    // ----------------------------- Structs ----------------------------- //
    struct LendingDuration {
        uint256 startTime;
        uint256 endTime;
    }

    // ----------------------------- Events ----------------------------- //
    event Lent(address indexed lender, address indexed borrower, uint256 indexed tokenId, uint256 startTime, uint256 endTime);
    event Collected(address indexed lender, uint256 indexed tokenId);
    event LendingTerminated(address indexed borrower, uint256 indexed tokenId);

    // ----------------------------- Constructor ----------------------------- //
    constructor(
        address _wrappedTokenAddress,
        string memory _name,
        string memory _symbol) ERC721(_name, _symbol) {
        wrappedToken = IERC721(_wrappedTokenAddress);
    }

    // ----------------------------- View Functions ----------------------------- //
    function underlyingToken() public view override returns (address) {
        return address(wrappedToken);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return wrappedToken.tokenURI(id);
    }

    function canBeCollected(
        uint256 _tokenId
    ) public view returns (bool) {
        require(originalOwner[_tokenId] != address(0), "Unmanaged Token Id"); // Results are invalid if token isn't being managed by this contract
        return virtualOwnerOf(_tokenId) == originalOwner[_tokenId];
    }

    function virtualOwnerOf(uint256 _tokenId) public view returns (address) {
        return virtualOwnerAtTime(_tokenId, block.timestamp);
    }

    // @notice Used to get the address of an unmanaged NFT, supports looking up other ILendWrappers.
    function getOwnerOfUnmanagedNFT(uint256 _tokenId) internal view returns (address) {
        address nftDirectOwner = wrappedToken.ownerOf(_tokenId);
        if (isContract(nftDirectOwner)) {
            if (IERC165(nftDirectOwner).supportsInterface(0x48bbd5ac)) { // Check for ILendWrapper interface
                return ILendWrapper(nftDirectOwner).virtualOwnerOf(_tokenId);
            }
        }
        return nftDirectOwner;
    }

    function virtualOwnerAtTime(uint256 _tokenId, uint256 _timeToCheck) public view returns (address) {
        if (originalOwner[_tokenId] != address(0)) { // This means that the tokenId is managed by this contract
            LendingDuration memory duration = lendingDurations[_tokenId];
            if (duration.endTime != 0 // duration is found and active
                && duration.startTime <= _timeToCheck && _timeToCheck < duration.endTime // duration is within time range
            ) {
                return ownerOf[_tokenId]; // owner of the wrapper NFT
            } else {
                return originalOwner[_tokenId]; // orignal owner of the wrapped NFT
            }
        } else {
            return getOwnerOfUnmanagedNFT(_tokenId); // unmanaged NFT - return owner as informed by the wrapped NFT
        }
    }

    // ----------------------------- Mutative Functions ----------------------------- //
    function lendOut(
        uint256 _tokenId,
        address _borrower,
        uint256 _startTime,
        uint256 _durationInSeconds
    ) external {
        require(_durationInSeconds != 0, "Duration must > 0");
        uint256 endTime = _startTime + _durationInSeconds;
        require(endTime > block.timestamp, "Lending period expired");

        originalOwner[_tokenId] = msg.sender;
        lendingDurations[_tokenId] = LendingDuration(_startTime, endTime);
        _mint(_borrower, _tokenId);

        emit Lent(msg.sender, _borrower, _tokenId, _startTime, endTime);

        wrappedToken.transferFrom(msg.sender, address(this), _tokenId);
    }

    function terminateLending(
        uint256 _tokenId
    ) external {
        require(ownerOf[_tokenId] == msg.sender, "Only borrower can terminate");
        require(block.timestamp < lendingDurations[_tokenId].endTime, "Lending already expired");
        delete lendingDurations[_tokenId];
        emit LendingTerminated(msg.sender, _tokenId);
    }


    function collect(
        uint256 _tokenId
    ) external {
        require(canBeCollected(_tokenId), "Token can't be collected");

        address owner = originalOwner[_tokenId];
        originalOwner[_tokenId] = address(0);
        delete lendingDurations[_tokenId];
        _burn(_tokenId);
        emit Collected(owner, _tokenId);

        wrappedToken.transferFrom(address(this), owner, _tokenId); // should be safe as it originated from the owner address
    }

    // ----------------------------- Utility ----------------------------- //
    /// @dev As a recipient of ERC721.safeTransfer();
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(wrappedToken), "Only supports wrapped");
        return IERC721Receiver(operator).onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return
            interfaceID == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceID == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceID == 0x5b5e139f || // ERC165 Interface ID for ERC721Metadata
            interfaceID == 0x48bbd5ac; // ERC165 Interface ID for ILendWrapper
    }

    function isContract(address addr) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}
