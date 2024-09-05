import fs from 'node:fs';

export async function getABI(contractName: string): Promise<any> {
    try {
        // Read the file
        const contractFile = JSON.parse(fs.readFileSync(`./artifacts/contracts/${contractName}.sol/${contractName}.json`, 'utf8'));

        // Get the ABI from the file
        return contractFile.abi;
    } catch (error) {
        console.error(`Error: Unable to find ABI for ${contractName}`);
        console.error(error);
    }
}
