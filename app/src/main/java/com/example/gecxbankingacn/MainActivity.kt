package com.example.gecxbankingacn

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.runtime.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            BankingApp()
        }
    }
}

@Composable
fun BankingApp() {
    var currentScreen by remember { mutableStateOf("dashboard") }
    
    MaterialTheme {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color(0xFFF8F9FB)
        ) {
            Box {
                if (currentScreen == "dashboard") {
                    BankingDashboard(onActivateClick = { currentScreen = "activate" })
                } else {
                    CreditCardActivation(onBack = { currentScreen = "dashboard" })
                }
            }
        }
    }
}

@Composable
fun BankingDashboard(onActivateClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "ACN Bank",
                style = MaterialTheme.typography.titleLarge.copy(
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF1A237E)
                )
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { }) {
                    Icon(Icons.Default.Notifications, contentDescription = "Notifications", tint = Color.Black)
                }
                Spacer(modifier = Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(Color.LightGray)
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
        Text(text = "Good Morning, Alex", color = Color.Gray, fontSize = 16.sp)
        Text(
            text = "$24,562.00",
            style = MaterialTheme.typography.headlineLarge.copy(
                fontWeight = FontWeight.Bold,
                fontSize = 36.sp,
                color = Color.Black
            )
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Credit Card Offer Card
        Card(
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onActivateClick() }
        ) {
            Box(
                modifier = Modifier
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Color(0xFF1A237E), Color(0xFF3949AB))
                        )
                    )
                    .padding(24.dp)
            ) {
                Column {
                    Text(
                        text = "Your Credit Card is Approved!",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "You applied via webchat. Start using your virtual card now.",
                        color = Color.White.copy(alpha = 0.8f),
                        fontSize = 14.sp
                    )
                    Spacer(modifier = Modifier.height(20.dp))
                    Surface(
                        color = Color.White,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            text = "Activate Card",
                            color = Color(0xFF1A237E),
                            modifier = Modifier.padding(horizontal = 24.dp, vertical = 10.dp),
                            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold)
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
        Text(
            text = "Recent Transactions",
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold, color = Color.Black)
        )
        Spacer(modifier = Modifier.height(16.dp))

        val transactions = listOf(
            Transaction("Grocery Store", "Today, 10:45 AM", "-$45.20", Color(0xFF42A5F5)),
            Transaction("Starbucks", "Today, 08:30 AM", "-$12.50", Color(0xFF66BB6A)),
            Transaction("Salary Deposit", "Yesterday", "+$4,500.00", Color(0xFFFFA726))
        )

        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(transactions) { tx ->
                TransactionItem(tx)
            }
        }
    }
}

@Composable
fun CreditCardActivation(onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        TextButton(onClick = onBack) {
            Text("< Back", color = Color.Gray)
        }
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Activate Your Card",
            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold, color = Color.Black)
        )
        Spacer(modifier = Modifier.height(24.dp))
        
        // Virtual Card
        Card(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            colors = CardDefaults.cardColors(containerColor = Color.Black)
        ) {
            Box(modifier = Modifier.padding(24.dp).fillMaxSize()) {
                Column(modifier = Modifier.align(Alignment.BottomStart)) {
                    Text("ALEX JOHNSON", color = Color.White, fontSize = 16.sp)
                    Text("**** **** **** 8829", color = Color.White.copy(alpha = 0.7f), fontSize = 18.sp, letterSpacing = 2.sp)
                }
                Text("VISA", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.TopEnd))
            }
        }
        
        Spacer(modifier = Modifier.height(40.dp))
        Text("Confirm Details", fontWeight = FontWeight.Bold, color = Color.Black)
        Spacer(modifier = Modifier.height(16.dp))
        OutlinedTextField(
            value = "$5,000.00",
            onValueChange = {},
            label = { Text("Credit Limit") },
            modifier = Modifier.fillMaxWidth(),
            readOnly = true
        )
        Spacer(modifier = Modifier.height(12.dp))
        OutlinedTextField(
            value = "14.99%",
            onValueChange = {},
            label = { Text("APR") },
            modifier = Modifier.fillMaxWidth(),
            readOnly = true
        )
        
        Spacer(modifier = Modifier.weight(1f))
        Button(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A237E)),
            shape = RoundedCornerShape(16.dp)
        ) {
            Text("Confirm & Activate", fontSize = 18.sp)
        }
    }
}

data class Transaction(val title: String, val date: String, val amount: String, val iconColor: Color)

@Composable
fun TransactionItem(tx: Transaction) {
    Surface(
        color = Color.White,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                modifier = Modifier.size(48.dp),
                shape = RoundedCornerShape(12.dp),
                color = tx.iconColor.copy(alpha = 0.1f)
            ) {
                Icon(
                    Icons.Default.ShoppingCart,
                    contentDescription = null,
                    modifier = Modifier.padding(12.dp),
                    tint = tx.iconColor
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(tx.title, fontWeight = FontWeight.Bold, color = Color.Black)
                Text(tx.date, color = Color.Gray, fontSize = 12.sp)
            }
            Text(
                tx.amount,
                fontWeight = FontWeight.Bold,
                color = if (tx.amount.startsWith("+")) Color(0xFF4CAF50) else Color.Black
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
fun DashboardPreview() {
    BankingApp()
}
