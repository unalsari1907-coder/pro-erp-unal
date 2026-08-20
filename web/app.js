// Satış & Alış Karşılaştırması
const ctxSales = document.getElementById('salesChart').getContext('2d');
new Chart(ctxSales, {
  type: 'bar',
  data: {
    labels: ['OCA', 'ŞUB', 'MAR', 'NİS'],
    datasets: [
      { label: 'Satış', data: [120, 150, 180, 200], backgroundColor: 'blue' },
      { label: 'Alış', data: [100, 130, 160, 170], backgroundColor: 'orange' }
    ]
  }
});

// Mevcut Stok
const ctxStock = document.getElementById('stockChart').getContext('2d');
new Chart(ctxStock, {
  type: 'pie',
  data: {
    labels: ['Depo A', 'Depo B', 'Depo C'],
    datasets: [{
      data: [320, 210, 150],
      backgroundColor: ['green', 'red', 'purple']
    }]
  }
});

// Kâr-Zarar
const ctxProfit = document.getElementById('profitChart').getContext('2d');
new Chart(ctxProfit, {
  type: 'line',
  data: {
    labels: ['OCA', 'ŞUB', 'MAR', 'NİS'],
    datasets: [{
      label: 'Kâr/Zarar',
      data: [12000, -8000, 5500, 9000],
      borderColor: 'darkgreen',
      fill: false
    }]
  }
});
