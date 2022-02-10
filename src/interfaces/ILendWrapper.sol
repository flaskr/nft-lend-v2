// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
    @notice ERC165 signature of ILendWrapper is `0x48bbd5ac`. This was the function used:
    `
    function calculateSelector() public pure returns (bytes4) {
        ILendWrapper i;
        return i.underlyingToken.selector ^ i.lendOut.selector
        ^ i.canBeCollected.selector ^ i.terminateLending.selector
        ^ i.collect.selector ^ i.virtualOwnerOf.selector
        ^ i.virtualOwnerAtTime.selector;
    }`
*/
interface ILendWrapper {
    /// @notice Returns the token address of the underlying token address
    function underlyingToken() external view returns (address);

    /**
        @notice Lends out an NFT for a given duration
        @param _tokenId tokenId of the NFT to be lent out
        @param _borrower address to send the lendWrapper token to
        @param _startTime epoch time to start the lending duration
        @param _durationInSeconds how long the lending duration will last
    */
    function lendOut(
        uint256 _tokenId,
        address _borrower,
        uint256 _startTime,
        uint256 _durationInSeconds
    ) external;

    /**
        @notice Called to check if tokenId can be collected. This is true if lending period has expired, or if the borrower terminated the lending period early.
        @param _tokenId tokenId of the NFT to be be returned
    */
    function canBeCollected(
        uint256 _tokenId
    ) external view returns (bool);

    /**
        @notice Called to surrender virtual ownership. Can only be called by current active borrower
        @param _tokenId tokenId of the NFT to be be returned
    */
    function terminateLending(
        uint256 _tokenId
    ) external;

    /**
        @notice Called to return tokenId to its owner. Can be called if `canBeCollected` is true
        @param _tokenId tokenId of the NFT to be be returned to owner
    */
    function collect(
        uint256 _tokenId
    ) external;

    /**
        @notice Returns the current virtual owner of the wrapped token
        @notice This might be susceptible to `block.timestamp` manipulation. Consider using function `virtualOwnerAtTime`
        @param _tokenId tokenId of the wrapper token
        @return Address of the current virtual owner
     */
    function virtualOwnerOf(uint256 _tokenId) external view returns (address);

    /**
        @notice Returns the virtual owner of the wrapped token at the given time, given current owner.
        @notice This sidesteps `block.timestamp` manipulation. But take note that ownership can be transferred before target time, and does not reflect future or past ownership.
        @param _tokenId tokenId of the wrapper token
        @param _timeToCheck tokenId of the wrapper token
        @return Address of the virtual owner at the given time, assuming that the ownership isn't transferred.
    */
    function virtualOwnerAtTime(uint256 _tokenId, uint256 _timeToCheck) external view returns (address);
}
