# Non-custodial NFT lending via pseudo-ownership
## Warning
The code in this repository is unaudited and is probably unsafe for use. Reference with care.

## Rational
NFTs can represent a wide variety of ownership of things. For example, a community membership, a perpetual ticket, real estate. 
And depending on how different parties use these NFTs, they can be used to enable event entry, right to enter raffles, showcase at various events.

An owner of an NFT may not be able to attend all events or enjoy all its benefits. 
As the number of use cases of NFTs grow, parties will begin to be interested in renting/lending out their NFTs to buyers and friends.
For example, if an owner happens to be out of the country for a particular party that requires NFT ownership, they could rent out their NFT for a day to allow someone else to attend the party instead.

## Overview
There are different types of NFT lending for different use cases, some mimic real-estate renting, some are backed by collateral.
What this project aims to provide is a building block for non-custodial lending of ERC-721 by introducing the concept of virtual ownership. 
This arrangement has the following properties:
* The borrower can never run away with the actual token.
* The lending period has a deadline. After which, virtual ownership belongs to the lender again.
* There can only be 1 virtual owner at any given time.
* The virtual custody can be transferred as it is implemented as an ERC-721.

Payment mechanisms for renting purposes are out of scope, but it is possible to on build on top of this mechanism.
For example, a contract can have ownership of a particular NFT, and allow borrowers to initiate the lending mechanism for a given duration, only if payment was made.

Apps and people can support non-custodial lending by simply using `getVirtualOwner(tokenId)` instead of `getOwner(tokenId)` to obtain the address of the current virtual owner.  

## Contracts
### LendWrapper.sol
A wrapper around a specific ERC-721 contract. Ownership token represents virtual ownership of the underlying token.
* Each Wrapper is associated with a specific ERC-721 token.
* A Wrapper token can only be minted to a target by depositing the associated ERC-721 token, with a specified lending duration.
  * The token-id will be the same as the wrapped token's token-id.
* The Wrapper token can be transferred from one person to another like a normal ERC-721 token.
* While the wrapper token exists and lending is active, `getVirtualOwner(tokenId)` function will reflect ownership as
  * token borrower, if lending is active
  * token lender, if lending is no longer active
  * the result from `tokenOwner.getVirtualOwner(tokenId)`, if actual tokenOwner is a contract supports the interface and is not this contract
    * actual token owner, if tokenOwner does not support this interface
* The wrapper token may be burnt to return the underlying token to its original owner
  * By anyone after lending duration is over, by calling `collect()`
