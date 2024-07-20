import { NDKUser } from "@nostr-dev-kit/ndk";
import {writable} from "svelte/store";

export const loggedUser = writable<NDKUser | null>(null);