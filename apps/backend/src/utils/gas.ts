import { Transaction } from 'thor-devkit';
import { thor } from './connex';

export type EstimateGasResult = {
  caller: string;
  gas: number;
  reverted: boolean;
  revertReason: string;
  vmError: string;
};

const getRevertReason = (output: Connex.VM.Output | undefined): string => {
  if (output) {
    if (output.revertReason) {
      return output.revertReason;
    }
    if (output.vmError) return output.vmError;
  }
  return '';
};

export const estimateGas = async (
  clauses: Connex.VM.Clause[],
  suggestedGas: number,
  caller: string,
  gasPayer?: string,
): Promise<EstimateGasResult> => {
  const intrinsicGas = Transaction.intrinsicGas(
    clauses.map(item => {
      return {
        to: item.to,
        value: item.value || 0,
        data: item.data || '0x',
      };
    }),
  );
  const offeredGas = suggestedGas ? Math.max(suggestedGas - intrinsicGas, 1) : 2000 * 10000;
  const explainer = thor.explain(clauses).caller(caller).gas(offeredGas);

  if (gasPayer) {
    explainer.gasPayer(gasPayer);
  }

  const outputs = await explainer.execute();
  let gas = suggestedGas;
  if (!gas) {
    const execGas = outputs.reduce((sum, out) => sum + out.gasUsed, 0);
    gas = intrinsicGas + (execGas ? execGas + 15000 : 0);
  }

  const lastOutput = outputs.slice().pop();

  return {
    caller,
    gas,
    reverted: lastOutput ? lastOutput.reverted : false,
    revertReason: getRevertReason(lastOutput),
    vmError: lastOutput ? lastOutput.vmError : '',
  };
};
