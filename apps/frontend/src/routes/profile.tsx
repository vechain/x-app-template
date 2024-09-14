import React, { useEffect, useState } from "react";
import { useWallet } from "@vechain/dapp-kit-react";

export default function Profile() {
    const { account } = useWallet();

    if (!account) {
        return <div className="absolute inset-0 h-full grid place-items-center ">
            <div className="flex flex-col place-content-center place-items-center text-white">

                <span className="mb-4">
                    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-lock"><rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></svg>

                </span>

                <span className="text-xl font-bold">
                    Please Login to view this page.
                </span>
            </div>
        </div>
    }
    return <div className="absolute inset-0 h-full max-w-sm">
        <div className="bg-white px-4 py-10 h-full flex flex-col">
            <div className="mb-auto space-y-4">

                <div className="flex place-items-center space-x-4">
                    <div className="w-10 h-10 bg-[#506c4c] rounded-full">
                    </div>
                    <h2 className="text-xl font-bold">name</h2>
                </div>
                <div className="space-y-2">
                    <div className="w-full h-10 rounded-md bg-[#506c4c] opacity-50"></div>
                    <div className="w-full h-10 rounded-md bg-[#506c4c] opacity-70"></div>
                    <div className="w-full h-10 rounded-md bg-[#506c4c] opacity-100"></div>
                </div>
                <div className="flex place-items-center space-x-4">
                    <div className="w-10 h-10 bg-[#506c4c] rounded-full">
                    </div>
                    <h2 className="text-xl font-bold">settings</h2>
                </div>
                <div className="flex place-items-center space-x-4 mb-auto">
                    <div className="w-10 h-10 bg-[#506c4c] rounded-full">
                    </div>
                    <h2 className="text-xl font-bold">awards</h2>
                </div>
            </div>
            <button className="bg-yellow-500 w-full rounded-lg py-2 text-extrabold">Logout</button>
        </div>
    </div>
}