import { MAX_SUBMISSIONS_PER_CYCLE, getAndDeployContracts, receiveAllocations, waitForNextCycle } from './helpers';
import { describe } from 'mocha';
import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('ecoearn', () => {
    describe('Contract parameters', () => {
        it('Should have max submissions per cycle set correctly', async () => {
            const { ecoearn } = await getAndDeployContracts();

            expect(await ecoearn.maxSubmissionsPerCycle()).to.equal(MAX_SUBMISSIONS_PER_CYCLE);
        });
    });

    describe('Allocations', () => {
        it('Should track allocations for a cycle correctly', async () => {
            const { ecoearn, token, x2EarnRewardsPool, appId, owner, admin } = await getAndDeployContracts();

            // Simulate receiving tokens from X Allocations Round
            await token.connect(owner).mint(admin, ethers.parseEther('6700'));

            // Allowance
            await token.connect(admin).approve(await x2EarnRewardsPool.getAddress(), ethers.parseEther('6700'));
            await x2EarnRewardsPool.connect(admin).deposit(ethers.parseEther('6700'), appId);

            // Set rewards for the current cycle
            await ecoearn.connect(admin).setRewardsAmount(await token.balanceOf(admin.address));

            await waitForNextCycle(ecoearn); // Assure cycle can be triggered

            await ecoearn.connect(admin).triggerCycle();

            expect(await ecoearn.getCurrentCycle()).to.equal(1);
        });

        it('Should track allocations for multiple cycles correctly', async () => {
            const { ecoearn, token, x2EarnRewardsPool, appId, owner, admin } = await getAndDeployContracts();

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            expect(await ecoearn.getCurrentCycle()).to.equal(1);

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            expect(await ecoearn.getCurrentCycle()).to.equal(2);
        });
    });

    describe('Rewards', () => {
        it('Should track valid submissions correctly', async () => {
            const { ecoearn, owner, admin, account3, token, x2EarnRewardsPool, appId } = await getAndDeployContracts();

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            await ecoearn.connect(admin).registerValidSubmission(owner.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account3.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(owner.address, ethers.parseEther('1'));

            expect(await ecoearn.submissions(await ecoearn.getCurrentCycle(), owner.address)).to.equal(2);

            expect(await ecoearn.submissions(await ecoearn.getCurrentCycle(), account3.address)).to.equal(1);

            expect(await ecoearn.submissions(2, owner.address)).to.equal(0); // No submissions for next cycle
        });

        it('Should be able to receive expected rewards', async () => {
            const { ecoearn, token, owner, account3, account4, admin, x2EarnRewardsPool, appId } = await getAndDeployContracts();

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            expect(await token.balanceOf(account4.address)).to.equal(ethers.parseEther('0'));
            expect(await token.balanceOf(account3.address)).to.equal(ethers.parseEther('0'));

            await ecoearn.connect(admin).registerValidSubmission(account4.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account3.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account4.address, ethers.parseEther('1'));

            expect(await token.balanceOf(account4.address)).to.equal(
                ethers.parseEther('2'), // Received 2 tokens
            );

            expect(await token.balanceOf(account3.address)).to.equal(
                ethers.parseEther('1'), // Received 1 token
            );
        });

        it('Should calculate correctly rewards left', async () => {
            const { ecoearn, token, owner, account3, admin, account4, otherAccounts, x2EarnRewardsPool, appId } = await getAndDeployContracts();

            await receiveAllocations(ecoearn, token, owner, admin, '50', x2EarnRewardsPool, appId); // Receive 50 tokens

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            expect(await ecoearn.rewardsLeft(1)).to.equal(ethers.parseEther('50')); // 50 tokens are for users

            await ecoearn.connect(admin).registerValidSubmission(owner.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account3.address, ethers.parseEther('1'));
            await ecoearn.connect(admin).registerValidSubmission(account3.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account4.address, ethers.parseEther('1'));
            await ecoearn.connect(admin).registerValidSubmission(account4.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(admin.address, ethers.parseEther('1'));
            await ecoearn.connect(admin).registerValidSubmission(admin.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(otherAccounts[0].address, ethers.parseEther('1'));

            expect(await ecoearn.rewardsLeft(1)).to.equal(ethers.parseEther('42'));
        });
    });

    describe('Withdrawals', () => {
        it("Should be able to withdraw if user's did not claim all their rewards", async () => {
            const { ecoearn, token, owner, admin, account3, x2EarnRewardsPool, appId } = await getAndDeployContracts();

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            await ecoearn.connect(admin).registerValidSubmission(owner.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(account3.address, ethers.parseEther('1'));

            await ecoearn.connect(admin).registerValidSubmission(owner.address, ethers.parseEther('1'));

            await waitForNextCycle(ecoearn);

            await receiveAllocations(ecoearn, token, owner, admin, '6700', x2EarnRewardsPool, appId);

            await waitForNextCycle(ecoearn);

            await ecoearn.connect(admin).triggerCycle();

            const initialBalance = await token.balanceOf(admin.address); // 6700 * 20% = 1340

            const rewardsLeftFirstCycle = await ecoearn.rewardsLeft(1); // 5345 tokens because 15 were claimed in the first cycle

            await ecoearn.connect(admin).withdrawRewards(1);

            expect(await token.balanceOf(admin.address)).to.equal(
                initialBalance + rewardsLeftFirstCycle, // 1340 + 5345 = 6685
            );
        });
    });
});
