import { NDKEvent } from '@nostr-dev-kit/ndk-mobile';
import { create, useStore } from 'zustand';
import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';

type ActiveEventStoreState = {
    activeEvent: NDKEvent | null;
    setActiveEvent: (event?: NDKEvent) => void;
};

/** Store */
export const activeEventStore = create<ActiveEventStoreState>((set) => ({
    activeEvent: null,
    setActiveEvent(event?: NDKEvent): void {
        set(() => ({ activeEvent: event }));
    },
}));

export const useActiveEventStore = () => {
    return useStore(activeEventStore);
}