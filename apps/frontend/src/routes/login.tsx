import React, { useEffect, useState } from "react";
import { useWallet } from "@vechain/dapp-kit-react";
import { useNavigate } from 'react-router-dom'

export default function Login() {
    const { account } = useWallet();
    const navigate = useNavigate()

    if (account) {
        navigate('/')
    }
    return <div className="absolute inset-0 h-full grid place-items-center text-xl font-bold md:font-extrabold">

        <div className=" " data-x="bg-emerald-500 px-5 md:px-24 shadow-lg rounded-2xl">
            <div className="max-w-xl bg-white p-8 rounded-2xl px-10">
                <h2 className="text-3xl font-bold text-green-800 mb-2">SG Odyssey</h2>

                <p className="text-green-700 mb-6 text-sm">
                    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                    incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud
                    exercitation ullamco laboris nisi ut aliquip.
                </p>
                <form className="space-y-4">
                    <input type="text" placeholder="Username" className="w-full px-4 py-3 rounded-full border-green-300 border" />
                    <input type="password" placeholder="Password" className="w-full px-4 py-3 rounded-full border-green-300 border" />

                    <button className="w-full bg-[#506c4c] text-white rounded-full py-3 hover:bg-green-700 transition-colors">

                        Login
                    </button>
                </form>
                <div className="mt-6 text-right">
                    <span className="inline-block transform rotate-45 text-orange-400 text-2xl">👣</span>
                </div>
            </div>
        </div>
    </div>
}