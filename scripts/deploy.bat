@echo off
REM Usage: deploy.bat <network> <treasury-address>
set TREASURY=%2
npx hardhat run scripts/deploy.js --network %1
