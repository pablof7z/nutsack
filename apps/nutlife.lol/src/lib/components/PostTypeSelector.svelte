<script>
    let visibleChoice;

    function change(e) {
        const { value } = e.target;

        visibleChoice = value;
    }
</script>

<div class="my-3">
    <select id="type" name="type" class="mt-1 block w-full rounded-md border-gray-900 py-2 pl-3 pr-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 text-black text-2xl"
        on:change={change}>
        <option selected>What do you want to share?</option>
        <option value="lodging">🛌 Lodging</option>
        <option value="airport">🚐 Transport from/to airport</option>
        <option value="coffee">☕️ meet for coffee</option>
        <option value="surfing">🏄 meet for surfing</option>
        <option value="climbing">🧗‍♀️ meet for climbing</option>
        <option value="psa">📢 general announce</option>
    </select>
</div>

{#if visibleChoice === 'lodging'}
<div id="lodging">
    <div class="flex flex-col md:flex-row">
        <div class="my-3 flex-1 md:mr-1">
            <label for="checkIn" class="block font-medium">Check-in date</label>
            <input type="date" name="checkIn" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
        </div>
    
        <div class="my-3 flex-1 md:ml-1">
            <label class="block font-medium">Check-out date</label>
            <input type="date" name="checkOut" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
        </div>
    </div>

    <div class="my-3">
        <label class="block font-medium">Hotel/Airbnb's URL (if any)</label>
        <input type="url" name="url" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
    </div>

    <div class="flex flex-col md:flex-row">
        <div class="my-3 flex-1 md:mr-1">
            <label class="block font-medium">Available rooms</label>
            <input type="number" name="roomsAvailable" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
        </div>
        <div class="my-3 flex-1 md:ml-1">
            <label class="block font-medium">⚡️ Total price (sats)</label>
            <input type="number" name="price" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
        </div>
    </div>
</div>
{:else if visibleChoice === 'airport'}
<div id="aiport">
    <div class="my-3">
        <label class="block font-medium">When?</label>
        <input type="date" name="date" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
    </div>
    <div class="my-3 flex-1 md:ml-1">
        <label class="block font-medium">⚡️ Total price (sats)</label>
        <input type="number" name="price" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
    </div>
</div>
{/if}

{#if !!visibleChoice}
<div class="my-3">
    <label for="title" class="block font-medium">Title</label>
    <input id="title" type="text" name="title" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3" placeholder="TL;DR" required minlength="5">
    <span class="text-sm text-gray-50">
        This will appear in the main page.
    </span>
</div>

{#if ['surfing', 'coffee', 'climbing'].includes(visibleChoice)}
<h3 class="text-lg font-semibold">
    Want to share when you'll be available?
</h3>
<div class="flex flex-col md:flex-row">
    <div class="my-3 flex-1 md:mr-1">
        <input type="date" name="checkIn" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
    </div>

    <div class="my-3 flex-1 md:ml-1">
        <input type="date" name="checkOut" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 text-black text-2xl py-3">
    </div>
</div>
{/if}

<div class="my-3">
    <label for="comment" class="block font-medium text-white">
        {#if visibleChoice === 'lodging'}
            <h3 class="text-lg font-semibold">
                Describe the arrangement a bit so nostriches
                booking know what to expect
            </h3>
        {:else}
            Add your comment
        {/if}
    </label>

    <div class="mt-1">
        <textarea rows="10" name="comment" id="comment" class="block w-full rounded-md border-gray-300 border shadow-sm focus:border-indigo-500 focus:ring-indigo-500 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 text-black" required minlength="10"></textarea>
    </div>
</div>
{/if}