import React, { useEffect, useState } from "react";
import { useWalletModal } from "@vechain/dapp-kit-react";
import { useWallet } from "@vechain/dapp-kit-react";

export default function Protected() {
    const { account } = useWallet();

    if (!account) {
        return <div>User must be logged in.</div>
    }

    return (
        <div>
            Welcome to the protected route!
        </div>
    );
}