// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library X2EarnAppsDataTypes {
    struct App {
        bytes32 id;
        string name;
        uint256 createdAtTimestamp;
    }

    struct AppWithDetailsReturnType {
        bytes32 id;
        address teamWalletAddress;
        string name;
        string metadataURI;
        uint256 createdAtTimestamp;
        bool appAvailableForAllocationVoting;
    }
}
