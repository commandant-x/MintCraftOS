# Synthetic renderer measurements

Baseline: `458a0f820c91c9822e52efb264ad041827f4ce31`. Candidate: 0.18.45, batch 8. Same Lua 5.2 interpreter and instrumented Lua terminal. These are rectangular workloads named for UI activity, **not actual application traces, Java API timings, Minecraft FPS or network bandwidth**. Static uses 1,001 presentations; other cases use 51. Counts include the byte-row capability probe. Times are accumulated CPU time from `os.clock`; heap is peak observed Lua heap above the pre-case baseline, with normal GC (not total allocations).


| Size | Synthetic scenario | Calls before/after | Raw pixel bytes before/after | Compose ms before/after | Present ms before/after | Peak heap KiB before/after |
|---|---|---:|---:|---:|---:|---:|
| 306x171 | static | 172 / 23 | 52327 / 52327 | 12.368 / 5.767 | 13.699 / 0.653 | 960.1 / 956.2 |
| 306x171 | move | 4508 / 1222 | 722251 / 159368 | 107.607 / 110.943 | 3.556 / 5.776 | 958.1 / 948.2 |
| 306x171 | resize | 4692 / 718 | 128763 / 75387 | 195.845 / 182.278 | 3.084 / 5.552 | 964.1 / 923.2 |
| 306x171 | terminal | 972 / 423 | 53703 / 53703 | 36.727 / 45.983 | 1.162 / 2.622 | 961.1 / 941.2 |
| 306x171 | editor | 972 / 423 | 53703 / 53703 | 43.974 / 37.380 | 1.903 / 1.901 | 961.1 / 941.2 |
| 306x171 | overlap | 572 / 73 | 53127 / 53127 | 46.218 / 41.765 | 0.811 / 1.715 | 946.1 / 944.2 |
| 306x171 | taskmanager | 572 / 73 | 53127 / 53127 | 29.179 / 23.410 | 0.959 / 1.307 | 935.1 / 956.2 |
| 306x171 | radar-simulated | 2016 / 1793 | 84034 / 80326 | 85.759 / 74.324 | 2.036 / 3.366 | 886.1 / 858.2 |
| 306x171 | navigation-simulated | 272 / 123 | 67627 / 67627 | 9.629 / 13.256 | 0.941 / 2.102 | 912.1 / 946.2 |
| 306x171 | open-close | 4422 / 573 | 702577 / 702577 | 107.006 / 116.793 | 3.735 / 5.876 | 957.1 / 946.2 |
| 306x171 | text-pixels | 8772 / 1173 | 2668677 / 2668677 | 111.845 / 11.196 | 7.803 / 8.862 | 958.1 / 951.2 |
| 306x171 | minimize-restore | 4422 / 573 | 702577 / 702577 | 106.730 / 132.453 | 3.421 / 7.861 | 957.1 / 936.2 |
| 480x270 | static | 271 / 35 | 129601 / 129601 | 16.936 / 5.678 | 19.271 / 0.709 | 958.1 / 954.2 |
| 480x270 | move | 7107 / 1930 | 1780657 / 298295 | 275.162 / 252.139 | 4.420 / 9.833 | 948.1 / 953.2 |
| 480x270 | resize | 7291 / 1050 | 252967 / 164791 | 476.434 / 443.031 | 5.229 / 8.839 | 955.1 / 932.2 |
| 480x270 | terminal | 1071 / 435 | 130977 / 130977 | 69.944 / 64.221 | 1.683 / 2.571 | 961.1 / 956.2 |
| 480x270 | editor | 1071 / 435 | 130977 / 130977 | 64.074 / 55.039 | 1.480 / 3.261 | 961.1 / 956.2 |
| 480x270 | overlap | 671 / 85 | 130401 / 130401 | 72.372 / 52.492 | 1.656 / 1.848 | 953.1 / 892.2 |
| 480x270 | taskmanager | 671 / 85 | 130401 / 130401 | 52.990 / 31.796 | 2.438 / 2.064 | 964.1 / 932.2 |
| 480x270 | radar-simulated | 2516 / 2295 | 144789 / 140270 | 165.564 / 147.456 | 3.071 / 5.337 | 948.1 / 945.2 |
| 480x270 | navigation-simulated | 371 / 135 | 153601 / 153601 | 15.165 / 11.358 | 0.887 / 1.578 | 921.1 / 930.2 |
| 480x270 | open-close | 7021 / 885 | 1749601 / 1749601 | 243.065 / 248.976 | 5.665 / 10.059 | 939.1 / 951.2 |
| 480x270 | text-pixels | 13821 / 1785 | 6609651 / 6609651 | 249.081 / 17.953 | 10.750 / 12.359 | 890.1 / 887.2 |
| 480x270 | minimize-restore | 7021 / 885 | 1749601 / 1749601 | 408.800 / 249.968 | 11.689 / 8.387 | 930.1 / 933.2 |
| 600x360 | static | 361 / 46 | 216001 / 216001 | 15.427 / 6.092 | 18.965 / 0.842 | 963.1 / 953.2 |
| 600x360 | move | 9447 / 2445 | 2955727 / 428855 | 426.299 / 480.569 | 8.099 / 20.056 | 1019.4 / 1173.9 |
| 600x360 | resize | 9631 / 1336 | 372637 / 260461 | 795.319 / 696.218 | 7.234 / 12.395 | 943.2 / 1159.2 |
| 600x360 | terminal | 1161 / 446 | 217377 / 217377 | 88.085 / 70.898 | 2.138 / 3.175 | 952.1 / 949.2 |
| 600x360 | editor | 1161 / 446 | 217377 / 217377 | 91.865 / 72.101 | 2.093 / 3.097 | 952.1 / 949.2 |
| 600x360 | overlap | 761 / 96 | 216801 / 216801 | 99.376 / 69.785 | 1.461 / 2.113 | 922.1 / 1036.9 |
| 600x360 | taskmanager | 761 / 96 | 216801 / 216801 | 55.067 / 41.049 | 2.096 / 2.563 | 913.1 / 937.2 |
| 600x360 | radar-simulated | 2611 / 2311 | 231079 / 226793 | 225.292 / 176.006 | 4.421 / 5.718 | 952.1 / 949.2 |
| 600x360 | navigation-simulated | 461 / 146 | 246001 / 246001 | 36.343 / 14.730 | 2.365 / 2.181 | 926.1 / 957.2 |
| 600x360 | open-close | 9361 / 1196 | 2916001 / 2916001 | 443.454 / 409.749 | 9.080 / 13.820 | 955.1 / 937.2 |
| 600x360 | text-pixels | 18411 / 2346 | 11016051 / 11016051 | 428.013 / 19.813 | 14.834 / 18.597 | 935.1 / 935.2 |
| 600x360 | minimize-restore | 9361 / 1196 | 2916001 / 2916001 | 474.351 / 378.803 | 9.368 / 12.108 | 955.1 / 937.2 |
| 960x540 | static | 541 / 69 | 518401 / 518401 | 27.469 / 5.581 | 23.642 / 1.032 | 1135.2 / 1156.8 |
| 960x540 | move | 14127 / 3568 | 7060627 / 856715 | 976.769 / 882.422 | 15.439 / 19.679 | 2258.2 / 2222.8 |
| 960x540 | resize | 14311 / 1929 | 770977 / 586801 | 2024.703 / 1682.330 | 15.732 / 17.996 | 2368.6 / 2436.5 |
| 960x540 | terminal | 1341 / 469 | 519777 / 519777 | 156.415 / 105.688 | 3.210 / 4.366 | 1141.9 / 1097.7 |
| 960x540 | editor | 1341 / 469 | 519777 / 519777 | 154.172 / 110.120 | 3.753 / 3.962 | 1141.9 / 1097.7 |
| 960x540 | overlap | 941 / 119 | 519201 / 519201 | 164.349 / 111.227 | 2.160 / 3.350 | 1833.9 / 2131.1 |
| 960x540 | taskmanager | 941 / 119 | 519201 / 519201 | 99.469 / 60.373 | 2.385 / 3.186 | 1068.0 / 1133.8 |
| 960x540 | radar-simulated | 2791 / 2326 | 532529 / 529274 | 330.898 / 290.315 | 3.847 / 6.467 | 951.1 / 954.7 |
| 960x540 | navigation-simulated | 641 / 169 | 566401 / 566401 | 42.540 / 27.840 | 2.607 / 4.059 | 1039.4 / 1085.0 |
| 960x540 | open-close | 14041 / 1769 | 6998401 / 6998401 | 984.231 / 986.861 | 15.122 / 22.601 | 1974.2 / 2060.9 |
| 960x540 | text-pixels | 27591 / 3519 | 26438451 / 26438451 | 983.977 / 32.074 | 28.744 / 30.090 | 1588.1 / 1575.2 |
| 960x540 | minimize-restore | 14041 / 1769 | 6998401 / 6998401 | 948.140 / 1020.850 | 12.488 / 21.251 | 1974.2 / 2083.2 |

Full-frame batch comparison: 60 alternating 960x540 frames; same process and mock API.

| Batch rows | Calls | Raw bytes | Present ms | Maximum batch pixel bytes | Observed heap KiB |
|---:|---:|---:|---:|---:|---:|
| 4 | 8101 | 31104001 | 55.442 | 3840 | 1867.3 |
| 8 | 4081 | 31104001 | 53.984 | 7680 | 1887.7 |
| 16 | 2041 | 31104001 | 49.901 | 15360 | 1853.2 |
| 32 | 1021 | 31104001 | 52.635 | 30720 | 1879.2 |

Eight rows is the conservative measured tradeoff: 4 reduces calls less, while 16/32 use larger temporary payloads. Timing winners varied between repeated local runs (8, 16 and 32); these microsecond differences on a Lua mock do not select the fastest Java call size. Eight limits a 960-wide batch to 7,680 pixel bytes. Stable disables batching. Measure on the actual modded server before selecting a larger batch.

The optimized path reduces API calls and often bytes, but some moving/resizing/radar workloads spend more CPU in Lua and some heap peaks rise. There is no blanket CPU, memory or frame-rate improvement claim. Event-driven scheduling avoids running these paths at all for nonvisual traffic. Running the same kernel integration harness against baseline and candidate dispatches all 1,000 modem events in both cases: baseline performs 1,001 desktop renders, candidate performs 1. Full application timings and event latency under real peripheral load remain to be measured.

