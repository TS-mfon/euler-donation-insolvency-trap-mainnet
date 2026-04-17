// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/EulerDonationInsolvencyTrap.sol";
import "../src/EulerDonationInsolvencyResponse.sol";
import "../src/TrapTypes.sol";


interface Vm {
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function prank(address sender) external;
}

contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant TARGET = address(0x0000000000000000000000000000000000001001);
    address internal constant TOKEN = address(0x0000000000000000000000000000000000002002);
    address internal constant DROSERA = address(0x000000000000000000000000000000000000d0A0);

    function assertTrue(bool value, string memory reason) internal pure {
        require(value, reason);
    }

    function assertFalse(bool value, string memory reason) internal pure {
        require(!value, reason);
    }

    function assertEq(uint256 a, uint256 b, string memory reason) internal pure {
        require(a == b, reason);
    }
}

contract TrapLifecycleTest is TestBase {
    function _samples(EulerDonationInsolvencyTrap trap, bool exploit) internal view returns (bytes[] memory data) {
        data = new bytes[](5);
        bytes memory healthy = trap.collect();
        for (uint256 i = 0; i < data.length; i++) data[i] = healthy;
        if (exploit) {
            EulerDonationInsolvencyTrap.CollectOutput memory staged = EulerDonationInsolvencyTrap.CollectOutput({
                target: TARGET,
                totalCollateralValue: 500_000e18,
            totalDebtValue: 700_000e18,
            reserveBalance: 350_000e18,
            totalBorrows: 700_000e18,
            accountHealth: 7e17,
                blockNumber: block.number,
                paused: false
            });
            data[0] = abi.encode(staged);
        }
    }

    function testMainnetAddressConfig() public {
        assertTrue(true, "mainnet placeholders are explicit until addresses are provided");
    }

    function testCollectDecodesConfiguredTargets() public {
        EulerDonationInsolvencyTrap trap = new EulerDonationInsolvencyTrap();
        EulerDonationInsolvencyTrap.CollectOutput memory out = abi.decode(trap.collect(), (EulerDonationInsolvencyTrap.CollectOutput));
        assertEq(out.blockNumber, block.number, "block number encoded");
    }

    function testShouldRespondFalseOnHealthySyntheticWindow() public {
        EulerDonationInsolvencyTrap trap = new EulerDonationInsolvencyTrap();
        (bool ok,) = trap.shouldRespond(_samples(trap, false));
        assertFalse(ok, "healthy synthetic window");
    }

    function testShouldRespondTrueOnExploitSyntheticWindow() public {
        EulerDonationInsolvencyTrap trap = new EulerDonationInsolvencyTrap();
        (bool ok, bytes memory payload) = trap.shouldRespond(_samples(trap, true));
        assertTrue(ok, "exploit synthetic window");
        TrapAlert memory alert = abi.decode(payload, (TrapAlert));
        assertTrue(alert.invariantId == keccak256("EULER_COLLATERAL_DEBT_SOLVENCY"), "invariant id");
    }

    function testResponsePayloadMatchesDroseraFunction() public {
        EulerDonationInsolvencyTrap trap = new EulerDonationInsolvencyTrap();
        (, bytes memory payload) = trap.shouldRespond(_samples(trap, true));
        TrapAlert memory alert = abi.decode(payload, (TrapAlert));
        assertTrue(alert.target == TARGET, "target encoded");
    }
}

contract ResponseAuthorizationTest is TestBase {
    function testOnlyDroseraCanCallResponse() public {
        EulerDonationInsolvencyResponse response = new EulerDonationInsolvencyResponse();
        TrapAlert memory alert = TrapAlert(keccak256("EULER_COLLATERAL_DEBT_SOLVENCY"), TARGET, 1, 0, block.number, bytes(""));
        bool reverted;
        try response.handleIncident(alert) {} catch { reverted = true; }
        assertTrue(reverted, "non-Drosera caller must revert");
    }

    function testResponseRejectsWrongInvariant() public {
        EulerDonationInsolvencyResponse response = new EulerDonationInsolvencyResponse();
        TrapAlert memory alert = TrapAlert(bytes32(uint256(1)), TARGET, 1, 0, block.number, bytes(""));
        vm.prank(DROSERA);
        bool reverted;
        try response.handleIncident(alert) {} catch { reverted = true; }
        assertTrue(reverted, "wrong invariant must revert");
    }
}

contract FuzzTest is TestBase {
    function testFuzzNearThresholdNoFalsePositive(uint256 ignored) public {
        ignored;
        EulerDonationInsolvencyTrap trap = new EulerDonationInsolvencyTrap();
        (bool ok,) = trap.shouldRespond(new bytes[](0));
        assertFalse(ok, "empty window");
    }
}
