@echo off
REM Usage: distribute.bat <network> <token-address> <recipients-file> [--dry-run]
npx hardhat run scripts/initialDistribution.js --network %1 -- %3 %2 %4
