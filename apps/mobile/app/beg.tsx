import { Button } from "@/components/nativewindui/Button";
import { NostrEvent, useNDK } from "@nostr-dev-kit/ndk-mobile";
import { NDKEvent } from "@nostr-dev-kit/ndk-mobile";
import { Text } from "@/components/nativewindui/Text";
import { useSearchParams } from "expo-router/build/hooks";
import { useState } from "react";
import { View } from "react-native";
import { TextInput } from "react-native-gesture-handler";
import { router, Stack } from "expo-router";
import { toast } from "@backpackapp-io/react-native-toast";

export default function Beg() {
    const { ndk } = useNDK();
    const searchParams = useSearchParams();
    const bolt11 = searchParams.get('bolt11');
    const [ text, setText ] = useState('pls sir, my familia, I am testing #honeypot and need some sats to try it out; can you spare some change, brother?');

    const send = () => {
        const event = new NDKEvent(ndk, {
            kind: 1,
            content: text + '\n\n' + bolt11,
            tags: [
                ["p", "fa984bd7dbb282f07e16e7ae87b26a2a7b9b90b7246a44771f0cf5ae58018f52"],
                ['t', 'honeypotapp']
            ]
        } as NostrEvent);
        event.publish().then(() => {
            toast.success('Post published');
            router.back();
        })
    }
    
    return (
        <>
            <View className="flex-row justify-between items-center p-4">
                <Text variant="heading" className="text-base text-muted-foreground font-bold">
                    Publish a post
                </Text>

                <Button variant="plain" size="sm" onPress={send}>
                    <Text>Send</Text>
                </Button>
            </View>
            <View className="flex-1 p-4">
                <TextInput
                    value={text}
                    onChangeText={setText}
                    className="flex-1"
                    multiline={true}
                    numberOfLines={4}
                    style={{ height: 100 }}
                />
            </View>
        </>
    )
}