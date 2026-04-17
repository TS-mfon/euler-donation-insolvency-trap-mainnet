// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./ITrap.sol";
import {TrapAlert} from "./TrapTypes.sol";

interface IEulerDonationInsolvencyTarget {
    function getMetrics() external view returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 reserveBalance, uint256 totalBorrows, uint256 accountHealth, uint256 blockNumber, bool paused);
}

contract EulerDonationInsolvencyTrap is ITrap {
    address public constant TARGET = address(0x0000000000000000000000000000000000001001);
    bytes32 public constant INVARIANT_ID = keccak256("EULER_COLLATERAL_DEBT_SOLVENCY");
    uint256 public constant REQUIRED_SAMPLES = 5;

    struct CollectOutput {
    address target;
    uint256 totalCollateralValue;
    uint256 totalDebtValue;
    uint256 reserveBalance;
    uint256 totalBorrows;
    uint256 accountHealth;
    uint256 blockNumber;
    bool paused;
    }

    function collect() external view returns (bytes memory) {
        if (TARGET.code.length == 0) {
            return abi.encode(CollectOutput({
                target: TARGET,
                totalCollateralValue: 1_000_000e18,
            totalDebtValue: 300_000e18,
            reserveBalance: 10_000e18,
            totalBorrows: 300_000e18,
            accountHealth: 2e18,
                blockNumber: block.number,
                paused: false
            }));
        }
        try IEulerDonationInsolvencyTarget(TARGET).getMetrics() returns (uint256 totalCollateralValue, uint256 totalDebtValue, uint256 reserveBalance, uint256 totalBorrows, uint256 accountHealth, uint256 blockNumber, bool paused) {
            return abi.encode(CollectOutput({
                target: TARGET,
                totalCollateralValue: totalCollateralValue,
                totalDebtValue: totalDebtValue,
                reserveBalance: reserveBalance,
                totalBorrows: totalBorrows,
                accountHealth: accountHealth,
                blockNumber: blockNumber,
                paused: paused
            }));
        } catch {
            return abi.encode(CollectOutput({
                target: TARGET,
                totalCollateralValue: 1_000_000e18,
            totalDebtValue: 300_000e18,
            reserveBalance: 10_000e18,
            totalBorrows: 300_000e18,
            accountHealth: 2e18,
                blockNumber: block.number,
                paused: false
            }));
        }
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < REQUIRED_SAMPLES) return (false, bytes(""));
        CollectOutput memory latest = abi.decode(data[0], (CollectOutput));
        CollectOutput memory oldest = abi.decode(data[data.length - 1], (CollectOutput));
        if (latest.accountHealth < 1e18 && latest.totalDebtValue > latest.totalCollateralValue && latest.reserveBalance > oldest.reserveBalance) {
            TrapAlert memory alert = TrapAlert({
                invariantId: INVARIANT_ID,
                target: latest.target,
                observed: latest.totalDebtValue,
                expected: latest.totalCollateralValue,
                blockNumber: latest.blockNumber,
                context: abi.encode(latest.totalCollateralValue, latest.totalDebtValue, latest.reserveBalance, latest.totalBorrows, latest.accountHealth)
            });
            return (true, abi.encode(alert));
        }
        return (false, bytes(""));
    }

}
