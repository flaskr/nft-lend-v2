// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "solmate/tokens/ERC721.sol";
import "ds-test/test.sol";
import "../LendWrapper.sol";
import "../../lib/solmate/src/test/utils/mocks/MockERC721.sol";

interface CheatCodes {
    function prank(address) external;
    function startPrank(address) external;
    function warp(uint) external;
}

contract ERC721WithURI is MockERC721 {
    constructor(string memory _name, string memory _symbol) MockERC721(_name, _symbol) {}
    function tokenURI(uint256) public pure virtual override returns (string memory) {
        return "expected-uri";
    }
}

contract LendWrapperTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    address owner;
    address user1;
    address user2;
    ERC721WithURI nft;
    LendWrapper lendWrapper;

    function setUp() public {
        owner = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        user1 = 0xe67003b84746A50B4f8EdF740E246A77eD191Dc3;
        user2 = 0x7c729FcfBc7A72622fcbFBe3bC5A4d772d789b0f;

        cheats.startPrank(owner);
        nft = new ERC721WithURI("Test NFT", "TEST");
        nft.mint(owner, 0);
        lendWrapper = new LendWrapper(address(nft), "wTEST", "wTEST");
        nft.approve(address(lendWrapper), 0);
        cheats.warp(1000);
    }

    function testVirtualOwnerBeforeLending() public {
        assertEq(owner, nft.ownerOf(0));
        assertEq(owner, lendWrapper.virtualOwnerOf(0));
        assertEq(owner, lendWrapper.virtualOwnerAtTime(0, block.timestamp));
    }

    function testLendOutToken(uint256 _randDuration, uint256 _randTimeAfterExpiry) public {
        uint nonZeroDuration = (_randDuration) % 1000 + 100;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);

        uint nonExpiringWaitTime = nonZeroDuration / 2; // wait for half of the lending duration
        cheats.warp(block.timestamp + nonExpiringWaitTime); // wait for part of the lending duration, such that lending is still active

        assertEq(address(lendWrapper), nft.ownerOf(0));
        assertEq(user1, lendWrapper.virtualOwnerOf(0));
        assertEq(user1, lendWrapper.virtualOwnerAtTime(0, block.timestamp));
        uint timeAfterExpiry = block.timestamp + _randDuration;
        assertEq(owner, lendWrapper.virtualOwnerAtTime(0, timeAfterExpiry));
    }

    function testVirtualOwnerIsOriginalOwnerBeforeLendingIsActive(uint _randDuration) public {
        uint futureStartTime = block.timestamp + (_randDuration) % 1000 + 1;
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, futureStartTime, nonZeroDuration);
        assertEq(address(lendWrapper), nft.ownerOf(0));
        assertEq(owner, lendWrapper.virtualOwnerOf(0));
    }

    function testAbleToObtainVirtualOwnerOfAnotherLendWrapper() public {
        // Create another lendWrapper
        LendWrapper anotherLendWrapper = new LendWrapper(address(nft), "wTEST2", "wTEST2");
        nft.approve(address(anotherLendWrapper), 0);
        cheats.warp(1000);

        anotherLendWrapper.lendOut(0, user1, block.timestamp, 1 days);
        assertEq(address(anotherLendWrapper), nft.ownerOf(0));
        assertEq(user1, anotherLendWrapper.virtualOwnerOf(0));
        assertEq(user1, lendWrapper.virtualOwnerOf(0));
    }

    function testFailLendingForZeroDuration() public {
        lendWrapper.lendOut(0, user1, block.timestamp, 0);
    }

    function testFailCreationOfExpiredLending(uint _divisor, uint _randDuration) public {
        uint nonZeroDivisor = (_divisor % 100) + 2;
        uint startTime = block.timestamp / nonZeroDivisor;
        uint nonZeroDuration = _randDuration % (block.timestamp - startTime);
        lendWrapper.lendOut(0, user1, startTime, nonZeroDuration);
    }

    function testVirtualOwnerCanBeTransferredWhileLendingIsActive(uint _randDuration) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        assertEq(user1, lendWrapper.virtualOwnerOf(0));

        cheats.prank(user1);
        lendWrapper.transferFrom(user1, user2, 0);
        assertEq(user2, lendWrapper.virtualOwnerOf(0));
    }

    function testVirtualOwnerIsOriginalOwnerAfterLendingIsExpired(uint _randDuration, uint _randTimeAfterExpiry) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        assertEq(user1, lendWrapper.virtualOwnerOf(0));
        uint timeAfterExpiry = block.timestamp + nonZeroDuration + 1 + _randTimeAfterExpiry % 10000;
        cheats.warp(timeAfterExpiry);
        assertEq(owner, lendWrapper.virtualOwnerOf(0));
    }

    function testFailOwnerCollectWrappedWhileLendingIsNotExpired(uint _randDuration) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        lendWrapper.collect(0);
    }

    function testOwnerCanCollectWrappedAfterLendingExpires(uint _randDuration, uint _randTimeAfterExpiry) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        assert(!lendWrapper.canBeCollected(0));

        cheats.warp(block.timestamp + nonZeroDuration + 1 + (_randTimeAfterExpiry % 1000000));
        assert(lendWrapper.canBeCollected(0));

        lendWrapper.collect(0);
        assertEq(owner, lendWrapper.virtualOwnerOf(0));
        assertEq(owner, nft.ownerOf(0));
    }

    function testFailNonVirtualOwnerTerminateLending(uint _randDuration) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        assert(!lendWrapper.canBeCollected(0));

        cheats.prank(user2);
        lendWrapper.terminateLending(0);
    }

    function testVirtualOwnerCanPrematurelyTerminateLending(uint _randDuration) public {
        uint nonZeroDuration = _randDuration + 1;
        lendWrapper.lendOut(0, user1, block.timestamp, nonZeroDuration);
        assert(!lendWrapper.canBeCollected(0));

        cheats.prank(user1);
        lendWrapper.terminateLending(0);

        assert(lendWrapper.canBeCollected(0));
        lendWrapper.collect(0);
        assertEq(owner, lendWrapper.virtualOwnerOf(0));
        assertEq(owner, nft.ownerOf(0));
    }
}
