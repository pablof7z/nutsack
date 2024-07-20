<script>
    import parse from 'date-fns/parse';
    import { intlFormat } from 'date-fns'
    
    export let date, endDate;
    let day, month, dayName;
    let endDay, endMonth, endDayName;

    let parsedDate = parse(date, 'yyyy-MM-dd', new Date());
    let parsedEndDate = parse(endDate, 'yyyy-MM-dd', new Date());

    day = intlFormat(parsedDate, { day: 'numeric'});
    month = intlFormat(parsedDate, { month: 'short'});
    dayName = intlFormat(parsedDate, { weekday: 'long'});

    if (endDate) {
        endDay = intlFormat(parsedEndDate, { day: 'numeric'});
        endMonth = intlFormat(parsedEndDate, { month: 'short'});
        endDayName = intlFormat(parsedEndDate, { weekday: 'long'});
    }
</script>

<div class="bg-white font-medium border-1">
    <div class="flex-none rounded-t lg:rounded-t-none lg:rounded-l text-center shadow-md">
        <div class="block rounded-t overflow-hidden text-center">
            <div class="bg-purple-900 text-xs font-semibold uppercase text-white py-1 whitespace-nowrap px-2">
                {#if month && endMonth && month !== endMonth }
                    {month} - {endMonth}
                {:else}
                    {month}
                {/if}
            </div>
            <div class="py-1 border-l border-r border-white bg-white">
                <span class="text-xl font-bold leading-tight px-2 whitespace-nowrap">
                    {#if day && endDay && day !== endDay }
                        {day} - {endDay}
                    {:else}
                        {day}
                    {/if}
                </span>
            </div>
            <!-- <div class="border-l border-r border-b rounded-b-lg text-center border-white bg-white -pt-2 -mb-1">
                <span class="text-sm">
                    {dayName}
                </span>
            </div> -->
        </div>
    </div>
</div>