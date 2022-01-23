# nft-lend

There are different types of NFT lending for different use cases, some mimic real-estate renting, some are backed by collateral.
What this project aims to provide is a building block for non-custodial lending. The borrower is never in full custody of the actual token. Hence, the lender's NFT is safu and the borrower can't run away with it. 
Instead, the token is sent to the Wrapper contract, and the contract provides an interface for services to check who has virtual custody of that token at the current moment. Virtual custody of the token can be traded as the wrapper contract is an ERC-721.

## Contracts
### ERC721Lender.sol
Primary interface for lending. This tracks a list of addresses and associates them with underlying LendWrappers. It works a little like an ERC-1155, and provides a central lookup to a correct wrapper address for given ERC-721s.
* Allow users to lend out their ERC-721s
* Allow services to look up current 'owner' of NFTs given the ERC-721 address and/or token-id
* Allow users to lookup the wrapper contract associated with the original ERC-721, in order to lookup more information like lending duration

### ERC721LendWrapper.sol
A wrapper around an ERC-721 that is an ERC-721. This token represents virtual custody of the underlying token.
* Each Wrapper is associated with a particular ERC-721 token.
* A Wrapper token can only be minted to a target by depositing the associated ERC-721 token, with a specified lending duration.
  * The token-id will be the same as the wrapped token's token-id.
* The Wrapper token can be transferred from one person to another like a normal ERC-721 token.
* While the wrapper token exists and lending is active, `getVirtualOwner(tokenId)` function will reflect ownership as
  * token borrower, if lending is active
  * token lender, if lending is no longer active
  * actual token owner, if token id is not in contract
* The wrapper token may be burnt to return the underlying token collector
  * By anyone after lending duration is over, by calling `collect`
  * By borrower at any time

## Deployed Contract(s)
| Network | Type | Address |
| --- | --- | --- |
| Ropsten Network | Lender | 0x1e83B1EB6C549353bdc9659737fEc6Ac5Fc500c0 |
