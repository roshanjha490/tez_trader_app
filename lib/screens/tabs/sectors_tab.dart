import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/sockets.dart';

import '../main_shell.dart'; 

// ignore: constant_identifier_names
const Map<String, List<String>> SECTORS = {
  "Banking": [
    "AUBANK",
    "AXISBANK",
    "BANDHANBNK",
    "BANKBARODA",
    "BANKINDIA",
    "CANBK",
    "FEDERALBNK",
    "HDFCBANK",
    "ICICIBANK",
    "IDFCFIRSTB",
    "INDIANB",
    "INDUSINDBK",
    "KOTAKBANK",
    "PNB",
    "RBLBANK",
    "SBIN",
    "UNIONBANK",
    "YESBANK",
  ],
  "NBFC / Financial Services": [
    "360ONE",
    "ABCAPITAL",
    "ANGELONE",
    "BAJFINANCE",
    "BAJAJFINSV",
    "BAJAJHLDNG",
    "BSE",
    "CDSL",
    "CHOLAFIN",
    "CAMS",
    "HDFCAMC",
    "IEX",
    "IRFC",
    "IREDA",
    "JIOFIN",
    "KFINTECH",
    "LTF",
    "LICHSGFIN",
    "MANAPPURAM",
    "MFSL",
    "MOTILALOFS",
    "MCX",
    "MUTHOOTFIN",
    "NAM_INDIA",
    "NUVAMA",
    "PAYTM",
    "POLICYBZR",
    "PNBHOUSING",
    "PFC",
    "RECLTD",
    "SAMMAANCAP",
    "SBICARD",
    "SHRIRAMFIN",
  ],
  "Insurance": ["HDFCLIFE", "ICICIGI", "ICICIPRULI", "LICI", "SBILIFE"],
  "IT / Software Services": [
    "COFORGE",
    "HCLTECH",
    "INFY",
    "KPITTECH",
    "LTM",
    "MPHASIS",
    "NAUKRI",
    "OFSS",
    "PERSISTENT",
    "TCS",
    "TATAELXSI",
    "TECHM",
    "WIPRO",
  ],
  "Pharma / Healthcare": [
    "ALKEM",
    "APOLLOHOSP",
    "AUROPHARMA",
    "BIOCON",
    "CIPLA",
    "DIVISLAB",
    "DRREDDY",
    "FORTIS",
    "GLENMARK",
    "LAURUSLABS",
    "LUPIN",
    "MANKIND",
    "MAXHEALTH",
    "SUNPHARMA",
    "TORNTPHARM",
    "ZYDUSLIFE",
  ],
  "FMCG / Consumer Staples": [
    "BRITANNIA",
    "COLPAL",
    "DABUR",
    "GODFRYPHLP",
    "GODREJCP",
    "HINDUNILVR",
    "ITC",
    "MARICO",
    "NESTLEIND",
    "PATANJALI",
    "TATACONSUM",
    "VBL",
  ],
  "Consumer Discretionary": [
    "AMBER",
    "ASIANPAINT",
    "ASTRAL",
    "BLUESTARCO",
    "CROMPTON",
    "DMART",
    "DIXON",
    "HAVELLS",
    "KALYANKJIL",
    "KAYNES",
    "NYKAA",
    "PGEL",
    "PAGEIND",
    "PIDILITIND",
    "POLYCAB",
    "RADICO",
    "SUPREMEIND",
    "TITAN",
    "TRENT",
    "UNITDSPR",
    "VMM",
    "VOLTAS",
  ],
  "Internet / New-Age": ["ETERNAL", "SWIGGY", "DELHIVERY"],
  "Auto & Auto Ancillaries": [
    "ASHOKLEY",
    "BAJAJ_AUTO",
    "BHARATFORG",
    "BOSCHLTD",
    "EICHERMOT",
    "EXIDEIND",
    "FORCEMOT",
    "HEROMOTOCO",
    "HYUNDAI",
    "M_M",
    "MARUTI",
    "MOTHERSON",
    "SONACOMS",
    "TVSMOTOR",
    "TMPV",
    "TIINDIA",
    "UNOMINDA",
  ],
  "Metals & Mining": [
    "APLAPOLLO",
    "HINDALCO",
    "HINDZINC",
    "JINDALSTEL",
    "JSWSTEEL",
    "NATIONALUM",
    "NMDC",
    "SAIL",
    "TATASTEEL",
    "VEDL",
    "COALINDIA",
  ],
  "Oil, Gas & Energy": [
    "BPCL",
    "GAIL",
    "HINDPETRO",
    "IOC",
    "ONGC",
    "OIL",
    "PETRONET",
    "RELIANCE",
  ],
  "Power / Utilities": [
    "ADANIENSOL",
    "ADANIGREEN",
    "ADANIPOWER",
    "JSWENERGY",
    "NHPC",
    "NTPC",
    "POWERGRID",
    "PREMIERENE",
    "TATAPOWER",
    "WAAREEENER",
    "SUZLON",
    "INOXWIND",
  ],
  "Capital Goods / Industrials": [
    "ABB",
    "BHEL",
    "CGPOWER",
    "CUMMINSIND",
    "GVT_D",
    "KEI",
    "LT",
    "POWERINDIA",
    "SIEMENS",
  ],
  "Defence & Aerospace": [
    "BDL",
    "BEL",
    "COCHINSHIP",
    "HAL",
    "MAZDOCK",
    "SOLARINDS",
  ],
  "Cement & Building Materials": [
    "AMBUJACEM",
    "DALBHARAT",
    "GRASIM",
    "SHREECEM",
    "ULTRACEMCO",
  ],
  "Chemicals & Agrochemicals": ["PIIND", "SRF", "UPL"],
  "Realty / Construction": [
    "DLF",
    "GODREJPROP",
    "LODHA",
    "NBCC",
    "OBEROIRLTY",
    "PHOENIXLTD",
    "PRESTIGE",
  ],
  "Infrastructure / Logistics / Transport": [
    "ADANIPORTS",
    "CONCOR",
    "GMRAIRPORT",
    "INDIGO",
    "RVNL",
  ],
  "Telecom": ["BHARTIARTL", "IDEA", "INDUSTOWER"],
  "Conglomerate / Diversified": ["ADANIENT"],
  "Hospitality": ["INDHOTEL"],
  "Consumer Food / QSR": ["JUBLFOOD"],
};

class SectorsTab extends StatefulWidget {
  const SectorsTab({super.key});

  @override
  State<SectorsTab> createState() => _SectorsTabState();
}

class _SectorsTabState extends State<SectorsTab> {
  StreamSubscription<Map<String, dynamic>>? _pricesSub;
  StreamSubscription<bool>? _statusSub;

  bool _isConnected = false;
  Map<String, dynamic> _livePrices = {};

  String _activeSector = "Banking";
  String _searchQuery = "";

  bool _isActive = false;

  @override
  void initState() {
    super.initState();

    _isConnected = sectorsSocket.isConnected;
    _statusSub = sectorsSocket.statusStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    if (sectorsPrices.hasSnapshot) {
      _livePrices = sectorsPrices.current;
    }

    _pricesSub = sectorsPrices.stream.listen((prices) {
      if (!mounted) return;
      setState(() => _livePrices = prices);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Sectors Tab is inside Markets Screen, which is Tab Index 1
    final isNowActive = ActiveTab.of(context) == 1;

    if (isNowActive && !_isActive) {
      _isActive = true;
      sectorsSocket.acquire(); // Connect!
      
      if (sectorsPrices.hasSnapshot) {
        _livePrices = sectorsPrices.current;
      }
    } else if (!isNowActive && _isActive) {
      _isActive = false;
      sectorsSocket.release(); // Disconnect!
    }
  }

  @override
  void dispose() {
    _pricesSub?.cancel();
    _statusSub?.cancel();
    
    if (_isActive) {
      sectorsSocket.release();
    }
    super.dispose();
  }

  // --- Logic Helpers ---
  double? _getSectorPerformance(String sector) {
    final symbols = SECTORS[sector] ?? [];
    double totalPct = 0;
    int activeCount = 0;

    for (var sym in symbols) {
      final data = _livePrices[sym];
      if (data != null && data['pct_change'] != null) {
        totalPct += (data['pct_change'] as num).toDouble();
        activeCount++;
      }
    }
    return activeCount > 0 ? (totalPct / activeCount) : null;
  }

  @override
  Widget build(BuildContext context) {
    final baseStocks = SECTORS[_activeSector] ?? [];
    final activeStocks = baseStocks
        .where((sym) => sym.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Column(
      children: [
        // 1. Horizontal Sector Selector (Mobile Equivalent of Left Sidebar)
        Container(
          height: 50,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: SECTORS.keys.length,
            itemBuilder: (context, index) {
              final sector = SECTORS.keys.elementAt(index);
              final isActive = _activeSector == sector;
              final avg = _getSectorPerformance(sector);
              final isPos = avg != null && avg >= 0;

              // Get the total number of stocks in this specific sector
              final stockCount = SECTORS[sector]?.length ?? 0;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _activeSector = sector;
                    _searchQuery = "";
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ), // Adjusted padding
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blueAccent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isActive
                          ? Colors.blueAccent.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Sector Name
                      Text(
                        sector,
                        style: TextStyle(
                          color: isActive ? Colors.blueAccent : Colors.white70,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),

                      // Sector Performance %
                      if (avg != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${isPos ? '+' : ''}${avg.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPos
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(width: 8),

                      // NEW: Stock Count Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.blueAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$stockCount',
                          style: TextStyle(
                            color: isActive
                                ? Colors.blueAccent
                                : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 2. Search & Status Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search stock...',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Live Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _isConnected
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'LIVE' : 'WAIT',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. The Grid/List of Stocks
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeStocks.length,
            itemBuilder: (context, index) {
              final symbol = activeStocks[index];
              final data = _livePrices[symbol];

              final double ltp = (data?['ltp'] as num?)?.toDouble() ?? 0.0;
              final double pct =
                  (data?['pct_change'] as num?)?.toDouble() ?? 0.0;
              final double open =
                  (data?['daily_open'] as num?)?.toDouble() ?? 0.0;
              final double high =
                  (data?['daily_high'] as num?)?.toDouble() ?? 0.0;
              final double low =
                  (data?['daily_low'] as num?)?.toDouble() ?? 0.0;

              final isPos = pct >= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    // Top Row: Symbol & LTP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹${ltp.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPos
                                    ? Colors.greenAccent.withOpacity(0.1)
                                    : Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${isPos ? '+' : ''}${pct.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  color: isPos
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Bottom Row: Intraday OHL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetric(
                          "O",
                          open.toStringAsFixed(1),
                          Colors.white54,
                        ),
                        _buildMetric(
                          "H",
                          high.toStringAsFixed(1),
                          Colors.greenAccent.withOpacity(0.7),
                        ),
                        _buildMetric(
                          "L",
                          low.toStringAsFixed(1),
                          Colors.redAccent.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper for small OHL metrics
  Widget _buildMetric(String label, String val, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          val,
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}