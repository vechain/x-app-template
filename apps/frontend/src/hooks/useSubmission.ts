import { create } from "zustand";
import { Response } from "../networking";

interface useSubmissionState {
  isLoading: boolean;
  response: Response | null;
  setIsLoading: (isLoading: boolean) => void;
  setResponse: (response: Response) => void;
  clearAll: () => void;
}

export const useSubmission = create<useSubmissionState>((set) => ({
  isLoading: false,
  response: null,
  setIsLoading: (isLoading) => set({ isLoading }),
  setResponse: (response) => set({ response }),
  clearAll: () => set({ isLoading: false, response: null }),
}));
