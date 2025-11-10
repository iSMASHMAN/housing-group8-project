% processHousingData.m
% Simple MATLAB script for Housing Group 8 project
% ------------------------------------------------
% 1. Load all project datasets placed in the data/ folder.
% 2. Run the required cleaning, statistics, and visualization steps on the
%    Housing dataset (Quantity, PricePerUnit, TotalSpent, Item, PaymentMethod).
% 3. Keep the script straightforward so the team can easily adapt it.

clear; clc; close all;

%% Load all provided datasets
dataDir = "data";
datasetNames = [
    "ZIP_Code_Population_Weighted_Centroids_1130336951148902581";
    "UnemploymentReport";
    "PovertyReport";
    "PopulationReport";
    "Housing";
    "Annual_Macroeconomic_Factors"
];

tables = struct();
for k = 1:numel(datasetNames)
    name = datasetNames(k);
    fieldName = matlab.lang.makeValidName(name);
    baseFile = fullfile(dataDir, name);

    if isfile(baseFile + ".xlsx")
        tables.(fieldName) = readtable(baseFile + ".xlsx", "TextType", "string");
    elseif isfile(baseFile + ".csv")
        tables.(fieldName) = readtable(baseFile + ".csv", "TextType", "string");
    else
        warning("Could not find %s (.xlsx or .csv).", name);
        tables.(fieldName) = table();
    end
end

% Pull the housing transactions table for the analysis below.
Thousing = tables.Housing;
if isempty(Thousing)
    error("The Housing dataset is required for the analysis but was not found.");
end

T = Thousing;

%% Treat common missing value markers
missingTokens = {"", "NA", "N/A", "na", "NaN", "nan", "null", "NULL", "-"};
T = standardizeMissing(T, missingTokens);

%% Convert numeric columns to numbers
numericVars = {"Quantity", "PricePerUnit", "TotalSpent"};
for k = 1:numel(numericVars)
    varName = numericVars{k};
    if ~ismember(varName, T.Properties.VariableNames)
        error("The column '%s' is missing from the dataset.", varName);
    end
    column = T.(varName);
    if iscell(column)
        column = string(column);
    end
    if isstring(column) || ischar(column)
        column = str2double(column);
    end
    T.(varName) = column;
end

%% Fix negative or inconsistent values
T.Quantity(T.Quantity < 0) = NaN;
T.PricePerUnit(T.PricePerUnit < 0) = NaN;

calculatedTotal = T.Quantity .* T.PricePerUnit;
needsUpdate = isnan(T.TotalSpent) | abs(T.TotalSpent - calculatedTotal) > 1e-6;
T.TotalSpent(needsUpdate) = calculatedTotal(needsUpdate);

%% Keep only rows with a valid TotalSpent value
Tclean = T(~isnan(T.TotalSpent), :);

%% Summary statistics for TotalSpent
fprintf("Summary statistics for Total Spent (cleaned data):\n");
metrics = {"Count", "Mean", "Standard Deviation", "Minimum", "Median", "Maximum", "Sum"}';
values = [sum(~isnan(Tclean.TotalSpent));
          mean(Tclean.TotalSpent, "omitnan");
          std(Tclean.TotalSpent, "omitnan");
          min(Tclean.TotalSpent, [], "omitnan");
          median(Tclean.TotalSpent, "omitnan");
          max(Tclean.TotalSpent, [], "omitnan");
          sum(Tclean.TotalSpent, "omitnan")];
summaryTable = table(metrics, values, 'VariableNames', {"Metric", "Value"});
disp(summaryTable);

%% Mostly sold items
itemCounts = groupsummary(Tclean, "Item", "IncludeMissingGroups", false);
[~, idxMostTransactions] = max(itemCounts.GroupCount);
itemMostTransactions = itemCounts.Item(idxMostTransactions);

itemQuantity = groupsummary(Tclean, "Item", "sum", "Quantity", "IncludeMissingGroups", false);
[~, idxMostQuantity] = max(itemQuantity.sum_Quantity);
itemMostQuantity = itemQuantity.Item(idxMostQuantity);

fprintf("Item with the most transactions: %s (%d transactions)\n", itemMostTransactions, itemCounts.GroupCount(idxMostTransactions));
fprintf("Item sold in the greatest total quantity: %s (%.2f units)\n", itemMostQuantity, itemQuantity.sum_Quantity(idxMostQuantity));

%% Most preferred payment method
validPayment = ~ismissing(Tclean.PaymentMethod);
paymentCounts = groupsummary(Tclean(validPayment, :), "PaymentMethod", "IncludeMissingGroups", false);
[~, idxPreferred] = max(paymentCounts.GroupCount);
preferredPayment = paymentCounts.PaymentMethod(idxPreferred);

fprintf("Most frequently used payment method: %s (%d transactions)\n", preferredPayment, paymentCounts.GroupCount(idxPreferred));

%% Visualizations
figure;
bar(categorical(itemQuantity.Item), itemQuantity.sum_Quantity);
title("Total Quantity Sold per Item");
xlabel("Item");
ylabel("Total Quantity");

grid on;

figure;
bar(categorical(itemCounts.Item), itemCounts.GroupCount);
title("Number of Transactions per Item");
xlabel("Item");
ylabel("Transactions");

grid on;

figure;
pie(paymentCounts.GroupCount, cellstr(paymentCounts.PaymentMethod));
title("Payment Method Distribution");

figure;
histogram(Tclean.TotalSpent, "BinMethod", "sturges");
title("Distribution of Total Spent");
xlabel("Total Spent");
ylabel("Frequency");

grid on;

%% Save cleaned data
outputFile = fullfile(dataDir, "Housing_cleaned.csv");
writetable(Tclean, outputFile);
fprintf("Cleaned data saved to %s\n", outputFile);
