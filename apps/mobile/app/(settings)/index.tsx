import { useNDK, useNDKCurrentUser, useNDKSession, useNDKWallet } from '@nostr-dev-kit/ndk-mobile';
import { Icon, MaterialIconName } from '@roninoss/icons';
import { useEffect, useMemo, useState } from 'react';
import { Platform, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';

import { LargeTitleHeader } from '~/components/nativewindui/LargeTitleHeader';
import { ESTIMATED_ITEM_HEIGHT, List, ListDataItem, ListItem, ListRenderItemInfo, ListSectionHeader } from '~/components/nativewindui/List';
import { Text } from '~/components/nativewindui/Text';
import { cn } from '~/lib/cn';
import { useColorScheme } from '~/lib/useColorScheme';
import { router } from 'expo-router';
import { ThemeToggle } from '@/components/ThemeToggle';
import * as User from '@/components/ui/user';
import { useUserProfile } from '@nostr-dev-kit/ndk-mobile';
import { formatMoney } from '@/utils/bitcoin';

export default function SettingsIosStyleScreen() {
    const { logout } = useNDK();
    const currentUser = useNDKCurrentUser();
    const { userProfile } = useUserProfile(currentUser?.pubkey);
    const { activeWallet, balance, setActiveWallet } = useNDKWallet();

    console.log('balance', balance);

    useEffect(() => {
        console.log('use effect balance', balance);
    }, [balance]);

    const appVersion = useMemo(() => {
        return `${Platform.OS} ${Platform.Version}`;
    }, []);
    // read the app version from expo's app.json
    const buildVersion = useMemo(() => {
        const appJson = require('../../app.json');
        return appJson.expo.version;
    }, []);

    const data = useMemo(() => {
        const opts = [
            {
                id: '2',
                title: 'Relays',
                leftView: <IconView name="wifi" className="bg-blue-500" />,
                onPress: () => router.push('/(settings)/relays'),
            },
        ];

        if (currentUser) {
            opts.unshift('gap 0');
            opts.unshift({
                id: '0',
                onPress: () => {
                    Clipboard.setStringAsync(currentUser.npub);
                },
                title: (
                    <View className="flex-row items-center gap-2">
                        <View className="flex-row">
                            <User.Avatar userProfile={userProfile} size={32} className="mr-2" />

                            <View className="flex-col">
                                <Text className="text-lg">
                                    {' '}
                                    <User.Name userProfile={userProfile} pubkey={currentUser.pubkey} />{' '}
                                </Text>
                                <Text className="text-muted-foreground font-mono text-xs mr-12">
                                    {currentUser.npub}
                                </Text>
                            </View>
                        </View>
                    </View>
                ),
            });

            opts.push({
                id: '11',
                title: 'Key',
                leftView: <IconView name="key-outline" className="bg-gray-500" />,
                onPress: () => router.push('/(settings)/key'),
            });
            opts.push('gap 3');
            opts.push({
                id: '12',
                title: 'Wallet',
                leftView: <IconView name="lightning-bolt" className="bg-green-500" />,
                rightText: balance ? formatMoney(balance) : activeWallet?.walletId,
                onPress: () => router.push('/(settings)/wallets'),
            });
            
            opts.push('gap 5');
            opts.push({
                id: '4',
                title: 'Logout',
                leftView: <IconView name="send-outline" className="bg-destructive" />,
                onPress: () => {
                    router.back();
                    setActiveWallet(null);
                    logout();
                },
            });
        }

        opts.push('gap 9');
        opts.push({
            id: 'version',
            title: `Version ${appVersion} (${buildVersion})`,
        });

        return opts;
    }, [currentUser, activeWallet, balance]);

    return (
        <>
            <LargeTitleHeader title="Settings" searchBar={{ iosHideWhenScrolling: true }} rightView={() => <ThemeToggle />} />
            <List
                contentContainerClassName="pt-4"
                contentInsetAdjustmentBehavior="automatic"
                variant="insets"
                data={data}
                estimatedItemSize={ESTIMATED_ITEM_HEIGHT.titleOnly}
                renderItem={renderItem}
                keyExtractor={keyExtractor}
                sectionHeaderAsGap
            />
        </>
    );
}

function renderItem<T extends (typeof data)[number]>(info: ListRenderItemInfo<T>) {
    if (typeof info.item === 'string') {
        return <ListSectionHeader {...info} />;
    }
    return (
        <ListItem
            className={cn('ios:pl-0 pl-2', info.index === 0 && 'ios:border-t-0 border-border/25 dark:border-border/80 border-t')}
            titleClassName="text-lg"
            leftView={info.item.leftView}
            rightView={
                <View className="flex-1 flex-row items-center justify-center gap-2 px-4">
                    {info.item.rightText && (
                        <Text variant="callout" className="ios:px-0 px-2 text-muted-foreground">
                            {info.item.rightText}
                        </Text>
                    )}
                    {info.item.badge && (
                        <View className="h-5 w-5 items-center justify-center rounded-full bg-destructive">
                            <Text variant="footnote" className="font-bold leading-4 text-destructive-foreground">
                                {info.item.badge}
                            </Text>
                        </View>
                    )}
                    <ChevronRight />
                </View>
            }
            {...info}
            onPress={() => info.item.onPress?.()}
        />
    );
}

function ChevronRight() {
    const { colors } = useColorScheme();
    return <Icon name="chevron-right" size={17} color={colors.grey} />;
}

export function IconView({ className, name, children }: { className?: string; name?: MaterialIconName; children?: React.ReactNode }) {
    return (
        <View className="px-3">
            <View className={cn('h-6 w-6 items-center justify-center rounded-md', className)}>
                {name ? <Icon name={name} size={15} color="white" /> : children}
            </View>
        </View>
    );
}

function keyExtractor(item: (Omit<ListDataItem, string> & { id: string }) | string) {
    return typeof item === 'string' ? item : item.id;
}
