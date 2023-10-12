// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";

//dependencies
import "contracts/ENSToken.sol";
import "contracts/ERC20MultiDelegate.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// HOW TO SETUP
// use the ENS code4rena repo found at https://github.com/code-423n4/2023-10-ens/commit/ed25379c06e42c8218eb1e80e141412496950685
// run "forge init --force"
// place this file at "tests" dir and run "forge test"

contract ENS_MultiDelegateTest is Test {
    ERC20Votes public token;
    ERC20MultiDelegate public multiDelegate;

    address public deployer;
    address public alice;
    address public bob;
    address public charlie;
    address public david;
    address public eve;

    uint256 public constant MINT_AMOUNT = 25 ether;

    function setUp() public {
        token = new ENSToken(10000 ether, 5000 ether, 0);
        multiDelegate = new ERC20MultiDelegate(
            token,
            "http://localhost:8080/{id}"
        );

        //setup users
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        david = makeAddr("david");
        eve = makeAddr("eve");

        //transfer Tokens
        vm.startPrank(deployer);
        token.transfer(alice, MINT_AMOUNT);
        token.transfer(bob, MINT_AMOUNT);
        vm.stopPrank();
    }

    /////////////////////////////Core Functions///////////////////////////////////
    function test_deposit() public {
        vm.startPrank(alice);
        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);

        uint256[] memory delegates = new uint256[](3);
        delegates[0] = uint256(uint160(bob));
        delegates[1] = uint256(uint160(charlie));
        delegates[2] = uint256(uint160(david));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2 ether;
        amounts[1] = 5 ether;
        amounts[2] = 3 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);
        //getVotes();
        //getERC1155BalanceForDelegate();

        //Delegate Once Again with extra ENS tokens
        amounts[0] = 3 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;
        multiDelegate.delegateMulti(sources, delegates, amounts);

        //getVotes();
        //getERC1155BalanceForDelegate();

        //Delegate Again to Different Delegates
        delegates[0] = uint256(uint160(deployer));
        delegates[1] = uint256(uint160(eve));
        delegates[2] = uint256(uint160(alice));

        multiDelegate.delegateMulti(sources, delegates, amounts);

        //getVotes();
        //getERC1155BalanceForDelegate();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT); //@audit-info -> this assertion will only hold good as long there is only a single user delegating
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );
        vm.stopPrank();
    }

    function test_delegateToAddressZero() public {
        vm.startPrank(alice);

        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);
        uint256[] memory delegates = new uint256[](2);

        delegates[0] = uint256(uint160(bob));
        delegates[1] = uint256(uint160(0));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 2.5 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);

        //getVotes();
        //getERC1155BalanceForDelegate();

        // //even though user delegates the tokens to address(0) they can redeem it back, since they arent sending it to the address(0) EOA rather the Proxy that will try to delegate to address(0)
        // multiDelegate.delegateMulti(targets, sources, amounts);
        // getVotes();
        // getERC1155BalanceForDelegate();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT); //@audit-issue -> assertion fails when the user delegates to address(0), since the getVotes() function does not count the tokens delegated to it.
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
    }

    function test_withdraw() public {
        vm.startPrank(alice);

        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);
        uint256[] memory targets = new uint256[](0);

        uint256[] memory delegates = new uint256[](3);
        delegates[0] = uint256(uint160(bob));
        delegates[1] = uint256(uint160(charlie));
        delegates[2] = uint256(uint160(david));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        amounts[2] = 5 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);
        //getVotes();

        //Partial Withdraw Test
        amounts[0] = 2.5 ether;
        amounts[1] = 2 ether;
        amounts[2] = 1 ether;
        multiDelegate.delegateMulti(delegates, targets, amounts);
        //getVotes();

        //Full Withdraw Test
        amounts[0] = multiDelegate.balanceOf(alice, uint160(bob));
        amounts[1] = multiDelegate.balanceOf(alice, uint160(charlie));
        amounts[2] = multiDelegate.balanceOf(alice, uint160(david));
        multiDelegate.delegateMulti(delegates, targets, amounts);

        //getVotes();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT);
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
    }

    function test_source_eq_target() public {
        //@audit-info -> Test when source and target array are of same length
        vm.startPrank(alice);
        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);

        uint256[] memory delegates = new uint256[](3);
        delegates[0] = uint256(uint160(bob));
        delegates[1] = uint256(uint160(charlie));
        delegates[2] = uint256(uint160(david));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        amounts[2] = 5 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);
        getVotes();

        //Test Partial Transfer
        uint256[] memory newDelegates = new uint256[](3);
        newDelegates[0] = uint256(uint160(alice));
        newDelegates[1] = uint256(uint160(deployer));
        newDelegates[2] = uint256(uint160(eve));

        amounts[0] = 2.5 ether;
        amounts[1] = 2.5 ether;
        amounts[2] = 2.5 ether;

        multiDelegate.delegateMulti(delegates, newDelegates, amounts);
        getVotes();

        //Test Full Transfer
        amounts[0] = token.getVotes(bob);
        amounts[1] = token.getVotes(charlie);
        amounts[2] = token.getVotes(david);

        multiDelegate.delegateMulti(delegates, newDelegates, amounts);
        getVotes();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT);
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
    }

    function test_source_lt_target() public {
        //@audit-info -> Test when source array length is less than target length
        vm.startPrank(alice);
        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);
        uint256[] memory targets = new uint256[](0);

        uint256[] memory delegates = new uint256[](2);
        delegates[0] = uint256(uint160(bob));
        delegates[1] = uint256(uint160(charlie));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);
        getVotes();

        //Test _processDelegation
        uint256[] memory newDelegates = new uint256[](3);
        newDelegates[0] = uint256(uint160(alice));
        newDelegates[1] = uint256(uint160(david));
        newDelegates[2] = uint256(uint160(eve));

        amounts = new uint256[](3);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        amounts[2] = 5 ether;

        multiDelegate.delegateMulti(delegates, newDelegates, amounts);
        //getVotes();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT);
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
    }

    function test_source_gt_target() public {
        //@audit-info -> Test when source array length is greater than target length
        vm.startPrank(alice);
        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);
        uint256[] memory targets = new uint256[](0);

        uint256[] memory delegates = new uint256[](3);
        delegates[0] = uint256(uint160(alice));
        delegates[1] = uint256(uint160(david));
        delegates[2] = uint256(uint160(eve));

        uint256[] memory amounts = new uint256[](3);
        amounts = new uint256[](3);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        amounts[2] = 5 ether;

        multiDelegate.delegateMulti(sources, delegates, amounts);
        getVotes();

        //Test _processDelegation
        uint256[] memory newDelegates = new uint256[](2);
        newDelegates[0] = uint256(uint160(bob));
        newDelegates[1] = uint256(uint160(charlie));

        amounts[0] = 5 ether;
        amounts[1] = 5 ether;
        amounts[2] = 5 ether;

        multiDelegate.delegateMulti(delegates, newDelegates, amounts);
        getVotes();

        assertEq(getTotalVotingPower() + token.balanceOf(alice), MINT_AMOUNT);
        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
    }

    function test_TwoUsersDelegate() public {
        vm.startPrank(alice);

        token.approve(address(multiDelegate), token.balanceOf(alice));

        uint256[] memory sources = new uint256[](0);

        uint256[] memory targets = new uint256[](2);
        targets[0] = uint256(uint160(charlie));
        targets[1] = uint256(uint160(david));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 5 ether;

        multiDelegate.delegateMulti(sources, targets, amounts);
        //getVotes();
        //getERC1155BalanceForDelegate();

        assertEq(
            getTotalERC1155Balance() + token.balanceOf(alice),
            MINT_AMOUNT
        );

        vm.stopPrank();
        //////////////////////////////////////
        vm.startPrank(bob);

        token.approve(address(multiDelegate), token.balanceOf(bob));

        targets = new uint256[](2);
        targets[0] = uint256(uint160(david));
        targets[1] = uint256(uint160(eve));

        amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;

        multiDelegate.delegateMulti(sources, targets, amounts);
        //getVotes();
        //getERC1155BalanceForDelegate();

        //assertEq(getTotalERC1155Balance() + token.balanceOf(bob), MINT_AMOUNT);

        vm.stopPrank();
    }

    /////////////////////////////////OnlyOwner/////////////////////////////////////////////

    function test_setUri() public {
        vm.prank(deployer);
        multiDelegate.setUri("http://localhost:8081/{id}");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        multiDelegate.setUri("http://localhost:8082/{id}");
    }

    ///////////////////////////////////Helper Function//////////////////////////////////////////

    function fetchBalance(address user) public {
        console2.log("ENS balance of : ", user, token.balanceOf(user));
    }

    function getVotes() public {
        //@audit-info -> Logs the current Voting Power of all users(invoke the function post multiDelegate.delegateMulti() function call to track the votes)
        console2.log(
            "---------------------------------------------------------------------------"
        );
        console2.log("Voting Power of each user");
        console2.log("Deployer:", token.getVotes(deployer));
        console2.log("Alice:", token.getVotes(alice));
        console2.log("Bob:", token.getVotes(bob));
        console2.log("Charlie:", token.getVotes(charlie));
        console2.log("David:", token.getVotes(david));
        console2.log("Eve:", token.getVotes(eve));
        console2.log("address(0):", token.getVotes(address(0)));
        console2.log(
            "---------------------------------------------------------------------------"
        );
    }

    function getTotalVotingPower() public returns (uint256) {
        return (token.getVotes(deployer) +
            token.getVotes(alice) +
            token.getVotes(bob) +
            token.getVotes(charlie) +
            token.getVotes(david) +
            token.getVotes(eve) +
            token.getVotes(address(0)));
    }

    function getERC1155BalanceForDelegate() public returns (uint256) {
        //@audit-info -> Logs the ERC1155 balances of all users(invoke the function post multiDelegate.delegateMulti() function call to track the votes)
        console2.log(
            "---------------------------------------------------------------------------"
        );
        console2.log("ERC1155 balance of each user");
        console2.log(
            "Deployer:",
            multiDelegate.getBalanceForDelegate(deployer)
        );
        console2.log("Alice:", multiDelegate.getBalanceForDelegate(alice));
        console2.log("Bob:", multiDelegate.getBalanceForDelegate(bob));
        console2.log("Charlie:", multiDelegate.getBalanceForDelegate(charlie));
        console2.log("David:", multiDelegate.getBalanceForDelegate(david));
        console2.log("Eve:", multiDelegate.getBalanceForDelegate(eve));
        console2.log(
            "address(0):",
            multiDelegate.getBalanceForDelegate(address(0))
        );
        console2.log(
            "---------------------------------------------------------------------------"
        );
    }

    function getTotalERC1155Balance() public returns (uint256) {
        return (multiDelegate.getBalanceForDelegate(deployer) +
            multiDelegate.getBalanceForDelegate(alice) +
            multiDelegate.getBalanceForDelegate(bob) +
            multiDelegate.getBalanceForDelegate(charlie) +
            multiDelegate.getBalanceForDelegate(david) +
            multiDelegate.getBalanceForDelegate(eve) +
            multiDelegate.getBalanceForDelegate(address(0)));
    }
}
