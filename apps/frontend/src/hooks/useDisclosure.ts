import { create } from "zustand";

interface useDisclosureState {
  isOpen: boolean;
  onOpen: () => void;
  onClose: () => void;
}

export const useDisclosure = create<useDisclosureState>((set) => ({
  isOpen: false,
  onOpen: () => set({ isOpen: true }),
  onClose: () => set({ isOpen: false }),
}));
