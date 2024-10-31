// Add this script section at the beginning of each page's script tag, right after the CONTRACT_ADDRESS declaration

// Utility functions for wallet connection persistence
const WALLET_CONNECTED_KEY = 'walletConnected';

// Check if wallet was previously connected
async function checkWalletConnection() {
    const wasConnected = localStorage.getItem(WALLET_CONNECTED_KEY);
    if (wasConnected === 'true' && typeof window.ethereum !== 'undefined') {
        await connectWallet();
    }
}

// Modified connectWallet function
async function connectWallet() {
    if (typeof window.ethereum !== 'undefined') {
        try {
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            const provider = new ethers.providers.Web3Provider(window.ethereum);
            signer = provider.getSigner();
            contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
            
            const address = await signer.getAddress();
            const connectButton = document.getElementById('connectWallet');
            connectButton.textContent = `${address.substring(0, 6)}...${address.substring(38)}`;
            
            // Save connection state
            localStorage.setItem(WALLET_CONNECTED_KEY, 'true');

            // Page specific initializations
            if (window.location.pathname.includes('index.html')) {
                // Admin page specific code
                const admin = await contract.admin();
                if (admin.toLowerCase() !== address.toLowerCase()) {
                    alert('Only admin can access this page');
                    window.location.href = 'user-dashboard.html';
                }
            } else if (window.location.pathname.includes('user-dashboard.html')) {
                // User dashboard specific code
                await updateTokenBalance();
                await loadQuestions();
                await loadInternships();
            } else if (window.location.pathname.includes('submissions.html')) {
                // Submissions page specific code
                await initializePage();
            }

        } catch (error) {
            console.error('Error connecting to wallet:', error);
            alert('Failed to connect wallet');
            localStorage.removeItem(WALLET_CONNECTED_KEY);
        }
    } else {
        alert('Please install MetaMask');
        localStorage.removeItem(WALLET_CONNECTED_KEY);
    }
}

// Add wallet disconnection handling
window.ethereum.on('accountsChanged', function (accounts) {
    if (accounts.length === 0) {
        // User disconnected wallet
        localStorage.removeItem(WALLET_CONNECTED_KEY);
        const connectButton = document.getElementById('connectWallet');
        connectButton.textContent = 'Connect Wallet';
    }
});

// Add network change handling
window.ethereum.on('chainChanged', function(networkId){
    // Refresh the page on network change
    window.location.reload();
});

// Initialize on page load
window.addEventListener('load', checkWalletConnection);