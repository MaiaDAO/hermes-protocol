week = 1;
const emission = 2
const target_base = 100
const tail_base = 1000
available = 1000000000
totalSupply = 0



function circulating_supply() {
  return totalSupply
}

function calculate_emission() {
  return available * emission / target_base
}

function weekly_emission() {
  return Math.max(calculate_emission(), circulating_emission())
}

function circulating_emission() {
  return circulating_supply() * emission / tail_base
}

while (week < 521) {
  _amount = weekly_emission();
  available -= _amount;
  totalSupply += _amount;
  console.log("week: ",week, " minted: ", _amount," available: ", available, " totalSupply: ", totalSupply)
  week++;
}
