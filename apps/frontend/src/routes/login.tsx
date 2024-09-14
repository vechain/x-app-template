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
        <div>
            Login page.
        </div>
    </div>
}