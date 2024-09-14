import React, { useEffect, useState } from "react";
import { useWallet } from "@vechain/dapp-kit-react";

export default function Settings() {
    const { account } = useWallet();

    if (!account) {
        return <div className="absolute inset-0 h-full grid place-items-center ">
            <div className="flex flex-col place-content-center place-items-center text-slate-500">

                <span className="mb-4">
                    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-lock"><rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></svg>

                </span>

                <span className="text-xl font-bold">
                    Please Login to view this page.
                </span>
            </div>
        </div>
    }
    return <div className="absolute inset-0 h-full grid place-items-center text-xl font-bold md:font-extrabold">Settings Page.</div>
}